module Oraora
  class Meta
    class Column
      def initialize(schema, relation, name)
        @schema = schema
        @relation = relation
        @name = name
      end

      def load_from_oci(oci)
        @id, @type, @length, @precision, @scale, @char_semantics =
          oci.select_one("SELECT column_id, data_type, data_length, data_precision, data_scale, char_used FROM dba_tab_columns WHERE owner = :schema AND table_name = :relation AND column_name = :name", @schema, @relation, @name)
        self
      end

      def self.from_oci(oci, schema, relation, name)
        new(schema, relation, name).load_from_oci(oci)
      end

      def describe
        puts <<-HERE.reset_indentation
          Schema:       #{@schema}
          Relation:     #{@relation}
          Name:         #{@name}
          Id:           #{@id}
          Type:         #{@type}(#{@length}/#{@precision},#{@scale})
        HERE
      end

      def list(filter = nil)
        raise NotApplicable, "Nothing to list for column"
      end
    end
  end
end