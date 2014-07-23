module Oraora
  module Terminal
    def self.width
      HighLine::SystemExtensions.terminal_size[0]
    end

    def self.height
      HighLine::SystemExtensions.terminal_size[1]
    end

    def self.puts_grid(items)
      # TODO: Disable terminal size check when not reading from terminal
      terminal_cols = [width, 32].max
      object_cols = terminal_cols / 32
      # TODO: Determine optimal object_cols
      num_rows = (items.length + object_cols - 1) / object_cols
      #@logger.debug "Determined #{num_rows} rows of #{object_cols} objects for #{items.count} objects and #{terminal_cols} terminal width"
      (0...num_rows).each do |row|
        line = ''
        (0...object_cols).each do |col|
          index = num_rows * col + row
          line += items[index].ljust(32) if items[index]
        end
        puts line
      end
    end

    def self.puts_cursor(cursor)
      # Column metadata
      column_names = cursor.get_col_names

      cursor.prefetch_rows = 1000
      begin
        # Fetch 1000 rows
        output = []
        column_lengths = Array.new(column_names.length, 1)
        while output.length < 1000 && record = cursor.fetch
          record.collect! { |val| val.is_a?(BigDecimal) ? val.to_s('F').gsub(/\.0+$/, '') : val.to_s }
          output << record
          column_lengths = column_lengths.zip(record.collect { |v| v.length}).collect(&:max)
        end

        # Output
        puts "%-*.*s  " * column_names.length % column_lengths.zip(column_lengths, column_names).flatten
        puts "%-*s  " * column_names.length % column_lengths.zip(column_lengths.collect { |c| '-' * c }).flatten
        output.each do |row|
          puts "%-*s  " * row.length % column_lengths.zip(row).flatten
        end
        puts
      end while record
    end
  end
end