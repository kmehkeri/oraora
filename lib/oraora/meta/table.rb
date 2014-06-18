require_relative './object.rb'

module Oraora
  class Meta
    class Table < Object
      def load_from_oci(oci)
        @partitioned = oci.select_one("SELECT partitioned FROM dba_tables WHERE owner = :schema AND table_name = :name", @schema, @name).first
        @columns = oci.pluck_one("SELECT column_name FROM dba_tab_columns WHERE owner = :schema AND table_name = :name ORDER BY column_id", @schema, @name)
        self
      end

      def describe
        puts <<-HERE.reset_indentation
          Schema:       #{@schema}
          Name:         #{@name}
          Partitioned:  #{@partitioned}
        HERE
      end

      def list(filter = nil)
        columns = @columns.select! { |o| o =~ /^#{Regexp.escape(filter).gsub('\*', '.*').gsub('\?', '.')}$/ } if filter
        Terminal.puts_grid(columns || @columns)
      end
    end
  end
end