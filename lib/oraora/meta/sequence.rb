require_relative './object.rb'

module Oraora
  class Meta
    class Sequence < Object
      def type
        'SEQUENCE'
      end

      def load_from_oci(oci)
        @min, @max, @inc, @last = oci.select_one("SELECT min_value, max_value, increment_by, last_number
                                                    FROM all_sequences
                                                   WHERE sequence_owner = :schema AND sequence_name = :name", @schema, @name)
        raise NotExists if !@min
        self
      end

      def describe(options = {})
        <<-HERE.reset_indentation
          Sequence #{@schema}.#{@name}
          Min value:    #{@min.to_i}
          Max value:    #{@max.to_i}
          Increment by: #{@inc.to_i}
          Last value:   #{@last.to_i}
        HERE
      end

      def list(options = {}, filter = nil)
        raise NotApplicable, "Nothing to list for sequence"
      end
    end
  end
end