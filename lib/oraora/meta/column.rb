module Oraora
  class Meta
    class Column
      attr_reader :id, :schema, :relation, :name,
                  :type, :length, :precision, :scale, :char_semantics

      def initialize(schema, relation, name)
        @schema = schema
        @relation = relation
        @name = name
      end

      def load_from_oci(oci)
        @id, @type, @length, @precision, @scale, @char_semantics =
          oci.select_one("SELECT column_id, data_type, data_length, data_precision, data_scale, char_used FROM dba_tab_columns WHERE owner = :schema AND table_name = :name AND column_name = :column", @schema, @relation, @name)
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

      def list
      end
    end
  end
end