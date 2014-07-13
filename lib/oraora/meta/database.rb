module Oraora
  class Meta
    class Database
      def load_from_oci(oci)
        @name, @created = oci.select_one("SELECT name, created FROM v$database")
        @schemas = oci.pluck_one("SELECT username FROM dba_users ORDER BY username")
        self
      end

      def self.from_oci(oci)
        new.load_from_oci(oci)
      end

      def describe
        <<-HERE.reset_indentation
          Database:     #{@name}
          Created:      #{@created}
        HERE
      end

      def list(filter = nil)
        schemas = @schemas.select! { |o| o =~ /^#{Regexp.escape(filter).gsub('\*', '.*').gsub('\?', '.')}$/ } if filter
        schemas || @schemas
      end
    end
  end
end