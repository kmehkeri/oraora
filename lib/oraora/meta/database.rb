module Oraora
  class Meta
    class Database
      attr_reader :name, :created, :schemas

      def load_from_oci(oci)
        @name, @created = oci.select_one("SELECT name, created FROM v$database")
        @schemas = oci.pluck("SELECT username FROM dba_users")
        self
      end

      def self.from_oci(oci)
        new.load_from_oci(oci)
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