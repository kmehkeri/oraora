module Oraora
  class App
    SQL_KEYWORDS = %w(select insert update delete merge create drop alter purge analyze commit rollback where add set)
    ORAORA_KEYWORDS = %w(c cd l ls d x exit su sudo)

    def initialize(credentials, role, logger)
      @credentials = credentials
      @user, @database, @role = credentials.user.upcase, credentials.database, (role ? role.upcase.to_sym : nil)
      @logger = logger
    end

    # Run the application with given credentials
    def run
      # Connect to Oracle
      @logger.debug "Connecting: #{@credentials}" + (@role ? " as #{@role}" : '')
      logon(@credentials.password)

      # Metadata engine
      @meta = Meta.new(@oci)

      # Set default context
      @context = Context.new(user: @user, schema: @user)

      # TODO: Add readline completion

      # Main loop
      buffer = ''
      while (line = Readline.readline(@context.prompt + (buffer == '' ? ' $ ' : ' % ')).strip) do
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

      @logger.debug "Exiting on end-of-file"
      terminate

    rescue Interrupt
      @logger.info "Interrupt"
      terminate
    end

    # Logon to the server
    #
    # Logon is wrapped in a separate thread as OCI8.new seems to ignore interrupts
    def logon(password)
      begin
        thread = Thread.new { @oci = OCI8.new(@user, password, @database, @role) }
        thread.join
      rescue Interrupt
        @logger.debug "CTRL+C, aborting logon"
        exit!
      end
    end

    # Log off the server and terminate
    #
    # Logoff is wrapped in a separate thread as OCI8.new seems to ignore interrupts
    def terminate
      @logger.debug "Logging off"
      thread = Thread.new { @oci.logoff if @oci }
      thread.join
      exit
    rescue Interrupt
      @logger.debug "Interrupt on logoff, force exit"
      exit!
    end

    # Process the command buffer
    def process(text)
      @logger.debug "Processing buffer: #{text}"
      # Determine first non-comment word of a command
      text =~ /\A(?:\/\*.*?\*\/\s*|--.*?(?:\n|\Z))*\s*([^[:space:]\*\(\/;]+)?(.*)?/mi
      case first_word = $1 && $1.downcase
        # Nothing, gibberish or just comments
        when nil
          if $2 && $2 != ''
            @logger.error "Invalid command: #{$2}"
          end

        # TODO: Change context
        when 'c', 'cd'
          @logger.debug "Switch context"
          if !$2 || $2.strip == ''
            @context.set(schema: @user)
          else
            path = $2.strip.split(/\s+/)[0].split(/[\.\/]/)
            begin
              @context = context_for(path)
            rescue Context::InvalidKey, Meta::NotExists
              @logger.error "Invalid path"
            end
          end

        when 'l', 'ls'
          # TODO: Context/filter by argument
          @logger.debug "List for #{@context.level} #{@context.instance_variable_get('@' + @context.level.to_s)}"
          # TODO: Disable terminal size check when not reading from terminal
          terminal_cols = HighLine::SystemExtensions.terminal_size[0]
          objects = @oci.describe_schema(@context.schema).objects.reject { |o| o =~ /\$/ }.collect(&:obj_name).sort
          object_cols = terminal_cols / 32
          # TODO: Determine optimal object_cols
          num_rows = (objects.length + object_cols - 1) / object_cols
          @logger.debug "Determined #{num_rows} rows of #{object_cols} objects for #{objects.count} objects and #{terminal_cols} terminal width"
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
          @logger.debug "Describe object"
          puts "Schema: #{@context[:schema]}"

        # Exit
        when 'x', 'exit'
          @logger.debug "Exiting on exit command"
          terminate

        # SQL
        when *SQL_KEYWORDS
          @logger.debug "Executing SQL"
          @logger.debug "#{text.gsub(/[;\/]\Z/, '')}"
          begin
            cursor = @oci.exec(text.gsub(/[;\/]\Z/, ''))
            if first_word == 'select'
              while record = cursor.fetch do
                puts record.join(', ')
              end
            end
          rescue OCI8::OCIError => e
            @logger.error "#{e.message} at #{e.parse_error_offset}"
          end

        # TODO: su
        when 'su'
          @logger.debug "Command type: su"

        # TODO: sudo
        when 'sudo'
          @logger.debug "Command type: sudo"

        # Unknown
        else
          @logger.error "Invalid command: #{$1}"
      end
    end

    # Returns new context relative to current one, traversing given path
    def context_for(path)
      new_context = @context
      level = path[0] == "" ? :root : new_context.level
      path.each_with_index do |node, i|
        case
          when i.zero? && node == '' then new_context.root
          when i.zero? && node == '~' then new_context.set(schema: @user)
          when node == '-' then new_context.up
          when node == '--' then new_context.up.up
          when node == '---' then new_context.up.up.up
          else
            raise Context::InvalidKey if node !~ /^[a-zA-Z0-9_\$]{,30}$/
            case new_context.level
              when nil then @meta.validate_schema(node) && new_context.traverse(schema: node)
              when :schema then (object_type = @meta.object_type(new_context.schema, node)) && new_context.traverse(object_type => node)
              when :table, :view, :mview then @meta.validate_column(new_context.schema, new_context.relation, node) && new_context.traverse(column: node)
              else raise Context::InvalidKey
            end
        end
      end
      new_context
    end
  end
end
