module Oraora
  class Meta
    class Schema
      def initialize(name)
        @name = name
      end

      def load_from_oci(oci)
        @id, @status, @created = oci.select_one("SELECT user_id, account_status, created FROM dba_users WHERE username = :name", @name)
        @id = @id.to_i
        @objects = oci.pluck("SELECT object_name, object_type FROM dba_objects WHERE owner = :name ORDER BY object_name", @name)
        self
      end

      def self.from_oci(oci, name)
        new(name).load_from_oci(oci)
      end

      def describe
        <<-HERE.reset_indentation
          Schema:       #{@name}
          Id:           #{@id}
          Status:       #{@status}
          Created:      #{@created}
        HERE
      end

      def list(filter = nil)
        objects = @objects.collect(&:first)
        objects.select! { |o| o =~ /^#{Regexp.escape(filter).gsub('\*', '.*').gsub('\?', '.')}$/ } if filter
        objects
      end
    end
  end
end