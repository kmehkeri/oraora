module Oraora
  class Meta
    class Column
      attr_reader :id, :schema, :package, :name

      def initialize(schema, package, name)
        @schema = schema
        @package = package
        @name = name
      end

      def load_from_oci(oci)
        @id =
            oci.select_one("SELECT subprogram_id FROM dba_procedues WHERE owner = :schema AND object_name = :package AND procedure_name = :name", @schema, @package, @name)
        self
      end

      def self.from_oci(oci, schema, package, name)
        new(schema, package, name).load_from_oci(oci)
      end

      def describe
        <<-HERE.reset_indentation
          Schema:       #{@schema}
          Package:      #{@package}
          Name:         #{@name}
          Id:           #{@id}
        HERE
      end

      def list(filter = nil)
        raise NotApplicable, "Nothing to list for subprogram"
      end
    end
  end
end