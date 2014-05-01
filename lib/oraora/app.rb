module Oraora
  class App
    SQL_KEYWORDS = %w(select insert update delete merge create drop alter purge analyze commit rollback where add set)
    ORAORA_KEYWORDS = %w(c cd l ls d x exit su sudo)

    # Application entry point, parses command line credentials and runs
    def self.main(credentials, role = nil)
      # TODO: read_passfile
      credentials = Credentials.parse(credentials)
      new.run(credentials, role)
    end

    # Run the application with given credentials
    def run(credentials, role)
      # Connect to Oracle with given credentials
      puts "[DEBUG] Connecting: #{credentials}" + (role ? " as #{role}" : '')
      @user, @database, @role = credentials.user.upcase, credentials.database, (role ? role.upcase.to_sym : nil)

      # Delegate login to a separate thread as OCI8.new seems to ignore interrupts
      begin
        thread = Thread.new { @oci = OCI8.new(@user, credentials.password, @database, @role) }
        thread.join
      rescue Interrupt
        thread.exit
        raise
      end

      # Metadata engine
      @meta = Meta.new(@oci)

      # Set default context
      @context = Context.new(user: @user, schema: @user)

      # TODO: Add readline completion

      # Main loop
      buffer = ''
      while (line = Readline.readline(@context.prompt).strip) do
        buffer += (buffer == '' ? '' : "\n") + line
        # Process buffer on one of these conditions:
        # * This is first line of the buffer and is empty
        # * This is first line of the buffer and is a Oraora command
        # * Entire buffer is a comment
        # * Line is '/' or ends with ';'
        if (buffer == line && (line =~ /^(#{ORAORA_KEYWORDS.join('|')})($|\s+)/ || line =~ /^\s*$/)) || line == '/' || line =~ /;$/ || buffer =~ /\A\s*--/ || buffer =~ /\A\s*\/\*.*\*\/\s*\Z/m
          process(buffer)
          buffer = ''
        end
      end

      puts "[DEBUG] Exiting on end-of-file"
      terminate

    rescue Interrupt
      puts "[INFO] Interrupt"
      terminate
    end

    def process(text)
      puts "[DEBUG] Processing buffer: #{text}"
      # Determine first non-comment word of a command
      text =~ /\A(?:\/\*.*?\*\/\s*|--.*?(?:\n|\Z))*\s*([^[:space:]\*\(\/;]+)?(.*)?/mi
      case first_word = $1 && $1.downcase
        # Nothing, gibberish or just comments
        when nil
          if $2 && $2 != ''
            puts "[ERROR] Invalid command: #{$2}"
          end

        # TODO: Change context
        when 'c', 'cd'
          puts "[DEBUG] Switch context"
          if !$2 || $2.strip == ''
            @context.set(schema: @user)
          else
            saved_context = @context.dup
            begin
              path = $2.strip.split(/\s+/)[0].split(/[\.\/]/)
              level = path[0] == "" ? :root : @context.level
              path.each_with_index do |node, i|
                case
                  when i.zero? && node == '' then @context.root
                  when i.zero? && node == '~' then @context.set(schema: @user)
                  when node == '-' then @context.up
                  when node == '--' then @context.up.up
                  when node == '---' then @context.up.up.up
                  else
                    raise Context::InvalidKey if node !~ /^[a-zA-Z0-9_\$]{,30}$/
                    case @context.level
                      when nil then @meta.validate_schema(node) && @context.traverse(schema: node)
                      when :schema then (object_type = @meta.object_type(@context.schema, node)) && @context.traverse(object_type => node)
                      when :table, :view, :mview then @meta.validate_column(@context.schema, @context.relation, node) && @context.traverse(column: node)
                      else raise Context::InvalidKey
                    end
                end
              end
            rescue Context::InvalidKey, Meta::NotExists
              puts "[ERROR] Invalid path"
              @context = saved_context
            end
          end

        when 'l', 'ls'
          puts "[DEBUG] List for #{@context.level} #{@context.instance_variable_get('@' + @context.level.to_s)}"
          # TODO: Context/filter by argument
          # TODO: Disable terminal size check when not reading from terminal
          terminal_cols = HighLine::SystemExtensions.terminal_size[0]
          objects = @oci.describe_schema(@context.schema).objects.reject { |o| o =~ /\$/ }.collect(&:obj_name).sort
          object_cols = terminal_cols / 32
          # TODO: Determine optimal object_cols
          num_rows = (objects.length + object_cols - 1) / object_cols
          puts "[DEBUG] Determined #{num_rows} rows of #{object_cols} objects for #{objects.count} objects and #{terminal_cols} terminal width"
          (0...num_rows).each do |row|
            line = ''
            (0...object_cols).each do |col|
              index = num_rows * col + row
              line += objects[index].ljust(32) if objects[index]
            end
            puts line
          end

        # TODO: Describe
        when 'd'
          puts "[DEBUG] Describe object"
          puts "Schema: #{@context[:schema]}"

        # Exit
        when 'x', 'exit'
          puts "[DEBUG] Exiting on exit command"
          terminate

        # SQL
        when *SQL_KEYWORDS
          puts "[DEBUG] Executing SQL"
          puts "[DEBUG] #{text.gsub(/[;\/]\Z/, '')}"
          begin
            cursor = @oci.exec(text.gsub(/[;\/]\Z/, ''))
            if first_word == 'select'
              while record = cursor.fetch do
                puts record.join(', ')
              end
            end
          rescue OCI8::OCIError => e
            puts "[ERROR] #{e.message} at #{e.parse_error_offset}"
          end

        # TODO: su
        when 'su'
          puts "[DEBUG] Command type: su"

        # TODO: sudo
        when 'sudo'
          puts "[DEBUG] Command type: sudo"

        # Unknown
        else
          puts "[ERROR] Invalid command: #{$1}"
      end
    end

    # Log off the server. 
    def terminate
      puts "[DEBUG] Logging off"
      thread = Thread.new { @oci.logoff if @oci }
      thread.join
      exit
    rescue Interrupt
      puts "[DEBUG] Interrupt on logoff, force exit"
      exit!
    end
  end
end
