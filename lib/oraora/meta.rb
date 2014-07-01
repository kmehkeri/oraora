module Oraora
  # Helper class wrapping OCI methods for querying metadata
  class Meta
    class NotExists < StandardError; end
    class NotApplicable < StandardError; end

    # Initializes with OCI
    def initialize(oci)
      @oci = oci
    end

    # Returns a node identified by context
    def find(context)
      case context.level
        when nil
          Meta::Database.from_oci(@oci)
        when :schema
          Meta::Schema.from_oci(@oci, context.schema)
        when :object
          Meta::Object.from_oci(@oci, context.schema, context.object, context.object_type)
        when :column
          col = context.column
          find(context.dup.up).columns(col)
      end
    end

    # Returns an object node identified by name
    def find_object(schema, name)
      Meta::Object.from_oci(@oci, schema, name)
    end
  end
end
