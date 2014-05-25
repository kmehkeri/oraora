module Oraora
  class Meta
    class Database
      attr_reader :name, :created

      def describe(oci)
        @name, @created = oci.select_one("SELECT name, created FROM v$database")
        @schemas = oci.pluck("SELECT username FROM all_users")
        self
      end
    end
  end
end