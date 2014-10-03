module Oraora
  class Meta
    class Schema
      def initialize(name)
        @name = name
      end

      def load_from_oci(oci)
        @id, @created = oci.select_one("SELECT user_id, created FROM all_users WHERE username = :name", @name)
        raise NotExists if !@id
        @id = @id.to_i
        @objects = oci.pluck("SELECT object_name, min(object_type) object_type FROM all_objects
                               WHERE owner = :name
                                 AND object_type IN ('TABLE', 'VIEW', 'MATERIALIZED VIEW', 'SEQUENCE')
                               GROUP BY object_name", @name)
        self
      end

      def self.from_oci(oci, name)
        new(name).load_from_oci(oci)
      end

      def describe(options = {})
        <<-HERE.reset_indentation
          Schema #{@name}
          Id:           #{@id}
          Created:      #{@created}
        HERE
      end

      def list(options = {}, filter = nil)
        objects = @objects.collect(&:first)
        objects.select! { |o| o =~ /^#{Regexp.escape(filter).gsub('\*', '.*').gsub('\?', '.')}$/ } if filter
        objects
      end
    end
  end
end