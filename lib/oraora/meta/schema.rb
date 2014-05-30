module Oraora
  class Meta
    class Schema
      attr_reader :id, :name, :status, :created

      def initialize(name)
        @name = name
      end

      def refresh(oci)
        if !@id
          @id, @status, @created = oci.select_one("SELECT user_id, account_status, created FROM dba_users WHERE username = :name", @name)
          @objects = Hash[ oci.pluck("SELECT object_name FROM dba_objects WHERE owner = :name", @name).collect { |obj| [obj, obj] } ]
        end
        self
      end

      def describe
        puts <<-HERE.reset_indentation
          Schema:       #{@name}
          Id:           #{@id}
          Status:       #{@status}
          Created:      #{@created}
        HERE
      end

      def list
        Terminal.puts_grid(@objects.keys.sort)
      end
    end
  end
end