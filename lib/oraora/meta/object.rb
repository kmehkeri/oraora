module Oraora
  class Meta
    class Object
      attr_reader :type

      def initialize(schema, name, type = nil)
        @schema = schema
        @name = name
        @type = type
      end

      def load_from_oci(oci)
        @id, @type = oci.select_one("SELECT object_id, object_type FROM dba_objects WHERE owner = :schema AND object_name = :name", @schema, @name) if !@type
        @id = @id && @id.to_i
        case @type
          when 'TABLE' then Table.from_oci(oci, @schema, @name)
          else self
        end
      end

      def self.from_oci(oci, schema, name, type = nil)
        new(schema, name, type).load_from_oci(oci)
      end

      def describe(options = {})
        <<-HERE.reset_indentation
          Schema:       #{@schema}
          Name:         #{@name}
          Id:           #{@id}
          Type:         #{@type}
        HERE
      end

      def list(options = {}, filter = nil)
        raise NotApplicable, "Cannot list for this object"
      end
    end
  end
end