module Oraora
  class Meta
    class Object
      attr_reader :id, :schema, :name, :type

      def initialize(schema, name)
        @schema = schema
        @name = name
      end

      def load_from_oci(oci)
        @id, @name, @type = oci.select_one("SELECT object_id, object_name, object_type FROM dba_objects WHERE owner = :schema AND object_name = :name", @schema, @name)
        self
      end

      def self.from_oci(oci, schema, name)
        new(schema, name).load_from_oci(oci)
      end

      def describe
        puts <<-HERE.reset_indentation
          Schema:       #{@schema}
          Name:         #{@name}
          Id:           #{@id}
          Type:         #{@type}
        HERE
      end

      def list
      end
    end
  end
end