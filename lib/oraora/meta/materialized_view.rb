require_relative './object.rb'

module Oraora
  class Meta
    class MaterializedView < Object
      def type
        'MATERIALIZED VIEW'
      end

      def load_from_oci(oci)
        @updatable, @refresh_mode, @fast_refreshable, @staleness =
            oci.select_one("SELECT updatable, refresh_mode, fast_refreshable, staleness
                              FROM all_mviews
                             WHERE owner = :schema AND mview_name = :name", @schema, @name)
        raise NotExists if !@updatable
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
          Materialized view #{@schema}.#{@name}
          Updatable:        #{@updatable}
          Refresh mode:     #{@refresh_mode}
          Fast refreshable: #{@fast_refreshable}
          Staleness:        #{@staleness}
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