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
    def pluck(sql, *bindvars)
      result = []
      exec(sql, *bindvars) { |row| result << row.first }
      result
    end

    # Returns a node identified by context
    def find(context)
      case context.level
        when nil then Meta::Database.from_oci(self)
        when :schema then Meta::Schema.from_oci(self, context.schema)
        when :object then Meta::Object.from_oci(self, context.schema, context.object)
        when :column then Meta::Column.from_oci(self, context.schema, context.object, context.column)
        when :subprogram then Meta::Subprogram.from_oci(self, context.schema, context.object, context.subprogram)
      end
    end
  end
end