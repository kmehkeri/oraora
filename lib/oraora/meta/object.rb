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
        if !@type
          @id, @type = oci.select_one("SELECT object_id, object_type FROM all_objects
                                        WHERE owner = :schema AND object_name = :name
                                        ORDER BY decode(namespace,  19, 0,  99)", @schema, @name) if !@type
          raise NotExists if !@id
          @id = @id.to_i
        end
        case @type
          when 'TABLE'              then Table.from_oci(oci, @schema, @name)
          when 'VIEW'               then View.from_oci(oci, @schema, @name)
          when 'MATERIALIZED VIEW'  then MaterializedView.from_oci(oci, @schema, @name)
          when 'SEQUENCE'           then Sequence.from_oci(oci, @schema, @name)
          else self
        end
      end

      def self.from_oci(oci, schema, name, type = nil)
        new(schema, name, type).load_from_oci(oci)
      end

      def describe(options = {})
        <<-HERE.reset_indentation
          Object #{@schema}.#{@name}
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