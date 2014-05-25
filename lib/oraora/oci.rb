module Oraora
  # Wrapper around OCI8 to add some extra stuff
  class OCI < OCI8
    # Wrapped in a separate thread as OCI8 seems to ignore interrupts
    def initialize(*args)
      ret = nil
      thread = Thread.new { ret = super }
      thread.join
      ret
    end

    # Wrapped in a separate thread as OCI8 seems to ignore interrupts
    def logoff
      ret = nil
      thread = Thread.new { ret = super }
      thread.join
      ret
    end

    # Wrapped in a separate thread with Interrupt handling
    def exec(sql, *bindvars, &block)
      ret = nil
      thread = Thread.new { ret = super }
      thread.join
      ret
    rescue Interrupt
      self.break
      raise
    end

    # Wrapped in a separate thread with Interrupt handling
    def select_one(sql, *bindvars)
      ret = nil
      thread = Thread.new { ret = super }
      thread.join
      ret
    rescue Interrupt
      self.break
      raise
    end

    # Returns a first column of a query as an array
    def pluck(sql)
      result = []
      exec(sql) { |row| result << row.first }
      result
    end
  end
end