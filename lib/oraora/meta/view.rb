require_relative './object.rb'

module Oraora
  class Meta
    class View < Object
      def type
        'VIEW'
      end

      def load_from_oci(oci)
        x = oci.select_one("SELECT 1 FROM all_views WHERE owner = :schema AND view_name = :name", @schema, @name).first
        raise NotExists if !x
        @columns = Hash[
            oci.pluck("SELECT column_name, column_id, data_type, data_length, data_precision, data_scale, char_used, char_length " +
                          "FROM all_tab_columns WHERE owner = :schema AND table_name = :name ORDER BY column_id", @schema, @name).collect do |col|
              [col[0], Column.new(@schema, @name, col[0], id: col[1].to_i, type: col[2], length: col[3] && col[3].to_i,
                                  precision: col[4] && col[4].to_i, scale: col[5] && col[5].to_i, char_used: col[6],
                                  char_length: col[7] && col[7].to_i)]
            end
        ]
        self
      end

      def describe(options = {})
        <<-HERE.reset_indentation
          View #{@schema}.#{@name}
        HERE
      end

      def list(options = {}, filter = nil)
        columns = @columns.keys
        columns.select! { |c| c =~ /^#{Regexp.escape(filter).gsub('\*', '.*').gsub('\?', '.')}$/ } if filter
        columns || @columns
      end

      def columns(column)
        raise NotExists if !@columns[column]
        @columns[column]
      end
    end
  end
end