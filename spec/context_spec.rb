require 'oraora/context'

describe Oraora::Context do

  describe '.initialize' do
    it "should initialize from hash" do
      context = Oraora::Context.new('V', schema: 'X', object: 'Y', object_type: 'TABLE')
      expect( context.level ).to eql :object
      expect( context.user ).to eql 'V'
      expect( context.schema ).to eql 'X'
      expect( context.object ).to eql 'Y'
      expect( context.object_type ).to eql 'TABLE'
    end
  end

  describe '.su' do
    it "should return a different context object" do
      context = Oraora::Context.new('V', schema: 'X', object: 'Y', object_type: 'TABLE')
      expect( context.su('Z') ).not_to eql context
    end

    it "should store specified user" do
      context = Oraora::Context.new('V', schema: 'X', object: 'Y', object_type: 'TABLE').su('Z')
      expect( context.user ).to eql 'Z'
    end

    it "should store original context's data" do
      context = Oraora::Context.new('V', schema: 'X', object: 'Y', object_type: 'TABLE').su('Z')
      expect( context.schema ).to eql 'X'
      expect( context.object ).to eql 'Y'
    end
  end

  describe '.dup' do
    it "should return equal context" do
      context = Oraora::Context.new('V', schema: 'X', object: 'Y', object_type: 'TABLE').dup
      expect( context.user ).to eql 'V'
      expect( context.schema ).to eql 'X'
      expect( context.object ).to eql 'Y'
      expect( context.object_type ).to eql 'TABLE'
    end
  end

  describe '#set & #traverse' do
    it "should set root context correctly" do
      context = Oraora::Context.new.set({})
      expect( context.level ).to be_nil
      expect( context.schema ).to be_nil
    end

    it "should set schema context correctly" do
      context = Oraora::Context.new.set(schema: 'A')
      expect( context.level ).to eql :schema
      expect( context.schema ).to eql 'A'
    end

    it "should set column context correctly" do
      context = Oraora::Context.new.set(schema: 'A', object: 'B', object_type: 'TABLE', column: 'C')
      expect( context.level ).to eql :column
      expect( context.schema ).to eql 'A'
      expect( context.object ).to eql 'B'
      expect( context.column ).to eql 'C'
    end

    it "should set user correctly on the context" do
      context = Oraora::Context.new('AA').set(schema: 'A')
      expect( context.level ).to eql :schema
      expect( context.user ).to eql 'AA'
      expect( context.schema ).to eql 'A'
    end

    it "should save user when switching context" do
      context = Oraora::Context.new('AA').set(schema: 'A')
      context.set(schema: 'B')
      expect( context.level ).to eql :schema
      expect( context.user ).to eql 'AA'
      expect( context.schema ).to eql 'B'
    end

    it "should raise error on invalid key" do
      expect { Oraora::Context.new.set(foo: 'A') }.to raise_exception(Oraora::Context::InvalidKey)
    end

    it "should raise error on missing object_type when object is present" do
      expect { Oraora::Context.new.set(schema: 'A', object: 'B') }.to raise_exception(Oraora::Context::InvalidKey)
    end

    it "should raise error on invalid combination of keys" do
      expect { Oraora::Context.new.set(schema: 'A', column: 'B', subprogram: 'C') }.to raise_exception(Oraora::Context::InvalidKey)
    end
  end

  describe "#up" do
    it "should do nothing when already at root" do
      context = Oraora::Context.new.up
      expect( context.level ).to be_nil
    end

    it "should go up from object to schema level" do
      context = Oraora::Context.new(nil, schema: 'A', object: 'B', object_type: 'TABLE').up
      expect( context.level ).to eql :schema
      expect( context.schema ).to eql 'A'
      expect( context.object ).to be_nil
    end

    it "should go up from column to object level" do
      context = Oraora::Context.new(nil, schema: 'X', object: 'Y', object_type: 'TABLE', column: 'Z').up
      expect( context.level ).to eql :object
      expect( context.schema ).to eql 'X'
      expect( context.object ).to be_eql 'Y'
      expect( context.column ).to be_nil
    end
  end

  describe '#prompt' do
    it "should display correct prompt for context" do
      {
        {}                                                                      => '/',
        { schema: 'Q' }                                                         => 'Q',
        { schema: 'U' }                                                         => '~',
        { schema: 'A', object: 'B', object_type: 'TABLE' }                      => 'A.B',
        { schema: 'U', object: 'B', object_type: 'PACKAGE' }                    => '~.B',
        { schema: 'U', object: 'Y', object_type: 'TABLE', column: 'Z' }         => '~.Y.Z',
        { schema: 'MMM', object: 'NNN', object_type: 'VIEW', column: 'TEST' }   => 'MMM.NNN.TEST'
      }.each do |hash, prompt|
        expect( Oraora::Context.new('U', hash).prompt ).to eql prompt
      end
    end
  end
end


