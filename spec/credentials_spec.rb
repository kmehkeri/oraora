require 'oraora/credentials'

describe Oraora::Credentials do
  describe '.parse' do
    it "should parse some standard combinations" do
      {
        ''                => Oraora::Credentials.new( nil,     nil,    nil),
        'user/pass@DB'    => Oraora::Credentials.new('user',  'pass', 'DB'),
        'user1@DB'        => Oraora::Credentials.new('user1',  nil,   'DB'),
        '/@DB'            => Oraora::Credentials.new( nil,     nil,   'DB'),
        '/'               => Oraora::Credentials.new( nil,     nil,    nil),
        '@DB'             => Oraora::Credentials.new( nil,     nil,   'DB')
      }.each do |str, result|
        expect( Oraora::Credentials.parse(str) ).to eql result
      end
    end

    it "should complain about incorrect format" do
      [
        'use!',
        'use!hey/pass',
        'use@DB/pass',
        'user/pass@@DB',
        'user/pass@DB*2'
      ].each do |str|
        expect { Oraora::Credentials.parse(str) }.to raise_exception(Oraora::Credentials::ParseError)
      end
    end
  end

  describe '#to_s' do
    it "should format credentials as string correctly" do
      expect( Oraora::Credentials.new( nil,     nil,    nil).to_s ).to eql '/'
      expect( Oraora::Credentials.new('user',  'pass', 'DB').to_s ).to eql 'user/pass@DB'
      expect( Oraora::Credentials.new('user1',  nil,   'DB').to_s ).to eql 'user1@DB'
      expect( Oraora::Credentials.new( nil,     nil,   'DB').to_s ).to eql '/@DB'
    end
  end

  describe '#match?' do
    it "should not match credentials with different user or db" do
      expect( Oraora::Credentials.new('foo', 'boo', 'DB').match?(Oraora::Credentials.new('foof', 'boo', 'DB')) ).to be false
      expect( Oraora::Credentials.new('foo', 'boo', 'DB').match?(Oraora::Credentials.new('foo', 'hoo', 'DB2')) ).to be false
    end


    it "should match credentials with the same user & db" do
      expect( Oraora::Credentials.new('foo', 'boo', 'DB').match?(Oraora::Credentials.new('foo', 'hoo', 'DB')) ).to be true
    end
  end

  context "passfile" do
    context "correct" do
      before(:each) do
        passfile = ['foo/boo@DB', 'hoo/hoo@DB', 'woo/hoohoo@XDB'].join("\n")
        allow(File).to receive(:open).with("passfile", "r").and_yield(StringIO.open(passfile))
        Oraora::Credentials.read_passfile('passfile')
      end

      it "should store credentials from passfile in the vault" do
        vault = ['foo/boo@DB', 'hoo/hoo@DB', 'woo/hoohoo@XDB'].collect { |entry| Oraora::Credentials.parse(entry) }
        expect( Oraora::Credentials.class_variable_get(:@@vault) ).to eql vault
      end

      it "should fill the password from the vault for matching entry" do
        expect( Oraora::Credentials.new('foo', nil, 'DB').fill_password_from_vault.password ).to eql 'boo'
      end
    end

    it "should return true if all entries are parsed correctly" do
      passfile = ['foo/boo@DB', 'hoo/hoo@DB', 'woo/hoohoo@XDB'].join("\n")
      allow(File).to receive(:open).with("passfile", "r").and_yield(StringIO.open(passfile))
      expect(Oraora::Credentials.read_passfile('passfile')).to be true
    end

    it "should return false if some entries have errors" do
      passfile = ['foo/boo@DB', 'hoo/hoo@@@@@DB2'].join("\n")
      allow(File).to receive(:open).with("passfile", "r").and_yield(StringIO.open(passfile))
      expect(Oraora::Credentials.read_passfile('passfile')).to be false
    end
  end
end

