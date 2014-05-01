require 'oraora/context'

describe Oraora::Context do

  describe '.initialize' do
    it "should initialize from hash" do
      context = Oraora::Context.new(user: 'V', schema: 'X', table: 'Y')
      expect( context.level ).to eql :table
      expect( context.user ).to eql 'V'
      expect( context.schema ).to eql 'X'
      expect( context.table ).to eql 'Y'
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
      context = Oraora::Context.new.set(schema: 'A', table: 'B', column: 'C')
      expect( context.level ).to eql :column
      expect( context.schema ).to eql 'A'
      expect( context.table ).to eql 'B'
      expect( context.column ).to eql 'C'
    end

    it "should set user correctly on the context" do
      context = Oraora::Context.new.set(user: 'AA', schema: 'A')
      expect( context.level ).to eql :schema
      expect( context.user ).to eql 'AA'
      expect( context.schema ).to eql 'A'
    end

    it "should save user when switching context" do
      context = Oraora::Context.new.set(user: 'AA', schema: 'A')
      context.set(schema: 'B')
      expect( context.level ).to eql :schema
      expect( context.user ).to eql 'AA'
      expect( context.schema ).to eql 'B'
    end

    it "should raise error on invalid key" do
      expect { Oraora::Context.new.set(foo: 'A') }.to raise_exception(Oraora::Context::InvalidKey)
    end

    it "should raise error on invalid combination of keys" do
      expect { Oraora::Context.new.set(schema: 'A', table: 'B', view: 'C') }.to raise_exception(Oraora::Context::InvalidKey)
    end
  end

  describe "#up" do
    it "should do nothing when already at root" do
      context = Oraora::Context.new.up
      expect( context.level ).to be_nil
    end

    it "should go up from table to schema level" do
      context = Oraora::Context.new(schema: 'A', table: 'B').up
      expect( context.level ).to eql :schema
      expect( context.schema ).to eql 'A'
      expect( context.table ).to be_nil
    end

    it "should go up from column to view level" do
      context = Oraora::Context.new(schema: 'X', view: 'Y', column: 'Z').up
      expect( context.level ).to eql :view
      expect( context.schema ).to eql 'X'
      expect( context.view ).to be_eql 'Y'
      expect( context.column ).to be_nil
    end
  end

  describe '#prompt' do
    it "should display correct prompt for context" do
      {
        {}                                                              => ' > ',
        { user: 'R', schema: 'Q' }                                      => 'Q > ',
        { user: 'Q', schema: 'Q' }                                      => '~ > ',
        { user: 'C', schema: 'A', table: 'B' }                          => 'A.B > ',
        { user: 'A', schema: 'A', package: 'B' }                        => '~.B > ',
        { user: 'X', schema: 'X', view: 'Y', column: 'Z' }              => '~.Y.Z > ',
        { user: 'M', schema: 'MMM', table: 'NNN', column: 'TEST' }      => 'MMM.NNN.TEST > ',
        { user: 'W', schema: 'W', procedure: 'V' }                      => '~.V > '
      }.each do |hash, prompt|
        expect( Oraora::Context.new(hash).prompt ).to eql prompt
      end
    end
  end
end


