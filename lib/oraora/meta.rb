require_relative 'meta/database'
require_relative 'meta/schema'

module Oraora
  # Helper class wrapping OCI methods for querying metadata
  class Meta
    class NotExists < StandardError; end

    def initialize(oci)
      @oci = oci
    end

    def validate_schema(schema)
      raise NotExists unless @oci.select_one('SELECT max(1) FROM all_users WHERE username = :username', schema)[0] == 1
      true
    end

    def object_type(schema, object)
      type = @oci.select_one("SELECT max(object_type) FROM all_objects WHERE owner = :schema AND object_name = :object AND object_type NOT IN ('PACKAGE BODY')", schema, object)[0]
      raise NotExists if !type
      type.downcase.gsub(' ', '_').to_sym
    end

    def validate_column(schema, relation, column)
      raise NotExists unless @oci.select_one('SELECT max(1) FROM all_tab_columns WHERE owner = :schema AND table_name = :relation AND column_name = :col', schema, relation, column)[0] == 1
      true
    end

    def database
      @database ||= Database.new.refresh(@oci)
    end

    def find(context, refresh = false)
      if context.level == nil
        database
      elsif context.schema
        schema = database.schemas[context.schema]
        schema.refresh(@oci)
        context.level == :schema ? schema : schema.find(context)
      end
    end
  end
end
