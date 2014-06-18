module Oraora
  class Meta
    class Object
      def initialize(schema, name)
        @schema = schema
        @name = name
      end

      def load_from_oci(oci)
        @id, @type = oci.select_one("SELECT object_id, object_type FROM dba_objects WHERE owner = :schema AND object_name = :name", @schema, @name)
        @id = @id.to_i
        case @type
          when 'TABLE' then Table.from_oci(oci, @schema, @name)
          else self
        end
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

      def list(filter = nil)
        raise NotApplicable, "Cannot list for this object"
      end
    end
  end
end