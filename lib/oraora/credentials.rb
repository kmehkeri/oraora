module Oraora
  class Credentials
    class ParseError < StandardError; end

    attr_reader :user, :password, :database
    @@vault = []

    def initialize(user = nil, password = nil, database = nil)
      @user = user
      @password = password
      @database = database
    end

    def self.read_passfile(filename)
      @@vault = []
      File.open("passfile", "r") do |infile|
        while (line = infile.gets)
          @@vault << parse(line.chomp)
        end
      end
    end

    def self.parse(str)
      if str
        match = str.match /^([^\/@]+)?\/?([^\/@]+)?@?([^\/@]+)?$/
        raise ParseError, "Invalid credentials format (use login/pass@DB)" if !match
        user, password, database = match[1..3]
        raise ParseError, "User can only contain alphanumeric characters" if user && !user.match(/^\w+$/)
        raise ParseError, "Database name can only contain alphanumeric characters" if database && !database.match(/^\w+$/)
        return new(user, password, database)
      else
        return new
      end
    end

    def fill_password_from_vault
      entry = @@vault.detect { |e| match?(e) }
      @password = entry.password if entry
      self
    end

    def to_s
      s = @user || ''
      s += '/' + @password if @password
      s = '/' if s == ''
      s += '@' + @database if @database
      s
    end

    def eql?(c)
      user == c.user && password == c.password && database == c.database
    end

    def match?(c)
      user == c.user && database == c.database
    end
  end
end
