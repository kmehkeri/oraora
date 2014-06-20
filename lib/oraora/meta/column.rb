module Oraora
  class Meta
    class Column
      CHAR_USED_MAP = { 'B' => 'BYTE', 'C' => 'CHAR' }
      attr_reader :name

      def initialize(schema, relation, name, attributes = {})
        @schema = schema
        @relation = relation
        @name = name
        attributes.each { |k, v| instance_variable_set("@#{k}".to_sym, v) }
      end

      def describe
        puts <<-HERE.reset_indentation
          Schema:       #{@schema}
          Relation:     #{@relation}
          Name:         #{@name}
          Id:           #{@id}
          Type:         #{display_type}
        HERE
      end

      def list(filter = nil)
        raise NotApplicable, "Nothing to list for column"
      end

      def display_type
        case @type
          when 'NUMBER'
            case
              when !@precision && !@scale then "NUMBER"
              when !@precision && @scale == 0 then "INTEGER"
              when @scale == 0 then "NUMBER(#{@precision})"
              else "NUMBER(#{@precision},#{@scale})"
            end
          when 'CHAR', 'NCHAR'
            @char_length == 1 ? 'CHAR' : "CHAR(#{@char_length} #{@char_used})"
          when 'VARCHAR', 'VARCHAR2', 'NVARCHAR2'
            "#{@type}(#{@char_length} #{CHAR_USED_MAP[@char_used]})"
          else
            @type
        end
      end
    end
  end
end