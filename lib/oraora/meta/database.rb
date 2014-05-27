module Oraora
  class Meta
    class Database
      attr_reader :name, :created, :schemas

      def refresh(oci)
        if !@name
          @name, @created = oci.select_one("SELECT name, created FROM v$database")
          @schemas = Hash[ oci.pluck("SELECT username FROM dba_users").collect { |schema| [schema, Schema.new(schema)] } ]
        end
        self
      end

      def describe
        puts <<-HERE.reset_indentation
          Database:     #{@name}
          Created:      #{@created}
        HERE
      end

      def list
        Terminal.puts_grid(@schemas.keys.sort)
      end
    end
  end
end