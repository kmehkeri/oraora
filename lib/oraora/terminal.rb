module Oraora
  module Terminal
    def self.puts_grid(items)
      # TODO: Disable terminal size check when not reading from terminal
      terminal_cols = [HighLine::SystemExtensions.terminal_size[0], 32].max
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
  end
end