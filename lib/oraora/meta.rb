module Oraora
  # Helper class wrapping OCI methods for querying metadata
  class Meta
    class NotExists < StandardError; end
    class NotApplicable < StandardError; end

    # Initializes with OCI
    def initialize(oci)
      @oci = oci
      @cache = {}
    end

    # Returns a node identified by context
    def find(context)
      node = case context.level
               when nil
                 @cache[context] || Meta::Database.from_oci(@oci)
               when :schema
                 @cache[context] || Meta::Schema.from_oci(@oci, context.schema)
               when :object
                 @cache[context] || Meta::Object.from_oci(@oci, context.schema, context.object, context.object_type)
               when :column
                 find(context.dup.up).columns(context.column)
             end
      @cache[context] = node if node && context.level != :column
      node
    end

    # Returns an object node identified by name
    def find_object(schema, name)
      Meta::Object.from_oci(@oci, schema, name)
    end

    # Removes all cached metadata
    def purge_cache
      @cache = {}
    end
  end
end
