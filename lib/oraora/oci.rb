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

    # Returns the query result as an array of arrays
    def pluck(sql, *bindvars)
      result = []
      exec(sql, *bindvars) { |row| result << row }
      result
    end

    # Returns first column of a query as an array
    def pluck_one(sql, *bindvars)
      result = []
      exec(sql, *bindvars) { |row| result << row.first }
      result
    end

    # Returns a node identified by context
    def find(context)
      case context.level
        when nil
          Meta::Database.from_oci(self)
        when :schema
          Meta::Schema.from_oci(self, context.schema)
        when :object
          Meta::Object.from_oci(self, context.schema, context.object, context.object_type)
        when :column
          col = context.column
          find(context.dup.up).columns(col)
        #when :subprogram
        #  Meta::Subprogram.from_oci(self, context.schema, context.object, context.subprogram)
      end
    end

    # Returns a node identified by name
    def find_object(schema, name)
      Meta::Object.from_oci(self, schema, name)
    end
  end
end