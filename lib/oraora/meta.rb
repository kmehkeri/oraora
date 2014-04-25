module Oraora
  # Helper module wrapping OCI methods for querying metadata
  module Meta
    def Meta.validate_schema(schema)
      true
    end

    def Meta.object_type(schema, object)
      :table
    end

    def Meta.validate_column(schema, relation, column)
      true
    end

    def Meta.program_type(schema, package, program)
      :procedure
    end
  end
end
