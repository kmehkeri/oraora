module Oraora
  class App
    class InvalidCommand < StandardError; end

    SQL_KEYWORDS = %w(select insert update delete merge truncate create drop alter purge analyze commit rollback where add set grant)
    ORAORA_KEYWORDS = %w(c cd l ls d x exit su sudo - -- --- .)

    def initialize(credentials, role, logger, context = nil)
      @credentials = credentials
      @user, @database, @role = credentials.user.upcase, credentials.database, (role ? role.upcase.to_sym : nil)
      @logger = logger
      @context = context || Context.new(@user, schema: @user)
    end

    # Run the application with given credentials
    def run(command = nil)
      # Connect to Oracle
      @logger.debug "Connecting: #{@credentials}" + (@role ? " as #{@role}" : '')
      logon

      # TODO: Add readline completion

      if command
        process(command)
      else
        # Main loop
        buffer = ''
        while !@terminate && line = Readline.readline(@context.prompt + ' ' + (buffer != '' ? '%' : (@role== :SYSDBA ? '#' : '$')) + ' ') do
          line.strip!
          Readline::HISTORY << line if line != '' # Manually add to history to avoid empty lines
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
      end

      if !@terminate
        @logger.debug "Exiting on end of input"
        terminate
      end

    rescue Interrupt
      @logger.warn "Interrupt"
      terminate
    end

    # Logon to the server
    def logon
      begin
        @oci = OCI.new(@user, @credentials.password, @database, @role)
        @meta = Meta.new(@oci)
      rescue Interrupt
        @logger.warn "CTRL+C, aborting logon"
        exit!
      end
    end

    # Log off the server and terminate
    def terminate
      if @oci
        @logger.debug "Logging off"
        @oci.logoff
      end
      @terminate = true
    rescue Interrupt
      @logger.warn "Interrupt on logoff, force exit"
      exit!
    end

    # Process the command buffer
    def process(text)
      @logger.debug "Processing buffer: #{text}"

      # shortcuts for '.' and '-'
      text = 'c ' + text if text =~ /^\s*(\.|\-+)\s*$/

      # Determine first non-comment word of a command
      text =~ /\A(?:\/\*.*?\*\/\s*|--.*?(?:\n|\Z))*\s*([^[:space:]\*\(\/;]+)?\s*(.*?)(?:[[:space:];]*)\Z/mi
      #          <------------- 1 --------------->    <--------- 2 -------->-   < 3 >
      # 1) strip '/* ... */' or '--' style comments from the beginning
      # 2) first word (any characters not being a space, '(', ';' or '*'), captured into $1
      # 3) remaining portion of a command, captured into $2

      case first_word = $1 && $1.downcase
        # Nothing, gibberish or just comments
        when nil
          if $2 && $2 != ''
            raise InvalidCommand, "Invalid command: #{$2}"
          end

        when 'c', 'cd'
          @logger.debug "Switch context"
          old_schema = @context.schema || @context.user
          if $2 && $2 != ''
            @context = context_for($2[/^\S+/])
          else
            @context.set(schema: @user)
          end
          @logger.debug "New context is #{@context.send(:key_hash)}"
          if old_schema != (@context.schema || @context.user)
            @logger.debug "Implicit ALTER SESSION SET CURRENT_SCHEMA = " + (@context.schema || @context.user)
            @oci.exec("ALTER SESSION SET CURRENT_SCHEMA = " + (@context.schema || @context.user))
          end

        when 'l', 'ls'
          @logger.debug "List"
          path = $2
          filter = $2[/[^\.\/]*(\*|\?)[^\.\/]*$/]
          path = path.chomp(filter).chomp('.').chomp('/')
          filter.upcase! if filter
          @logger.debug "Path: #{path}, Filter: #{filter}"
          work_context = path && path != '' ? context_for(path[/^\S+/]) : @context
          @logger.debug "List for #{work_context.level || 'database'}"
          @meta.find(work_context).list(filter)

        when 'd', 'desc', 'describe'
          @logger.debug "Describe"
          work_context = $2 && $2 != '' ? context_for($2[/^\S+/]) : @context
          @logger.debug "Describe for #{work_context.level || 'database'}"
          @meta.find(work_context).describe

        # Exit
        when 'x', 'exit'
          @logger.debug "Exiting on exit command"
          terminate

        # SQL
        when *SQL_KEYWORDS
          @logger.debug "SQL: #{text.gsub(/[;\/]\Z/, '')}"
          res = @oci.exec(text.gsub(/[;\/]\Z/, ''))

          if first_word == 'select'
            # Column metadata
            column_names = res.get_col_names

            res.prefetch_rows = 1000
            begin
              # Fetch 1000 rows
              output = []
              column_lengths = Array.new(column_names.length, 1)
              while output.length < 1000 && record = res.fetch
                output << record
                column_lengths = column_lengths.zip(record.collect { |v| v.to_s.length}).collect(&:max)
              end

              # Output
              puts "%-*.*s  " * column_names.length % column_lengths.zip(column_lengths, column_names).flatten
              puts "%-*s  " * column_names.length % column_lengths.zip(column_lengths.collect { |c| '-' * c }).flatten
              output.each do |row|
                puts "%-*s  " * row.length % column_lengths.zip(row).flatten
              end
              puts
            end while record

          else
            @logger.info "#{res} row(s) affected"
          end

        when 'su'
          @logger.debug "Command type: su"
          su

        when 'sudo'
          @logger.debug "Command type: sudo (#{$2})"
          raise InvalidCommand, "Command required for sudo" if $2.strip == ''
          su($2)

        # Unknown
        else
          raise InvalidCommand, "Invalid command: #{$1}"
      end

    rescue InvalidCommand, Meta::NotApplicable => e
      @logger.error e.message
    rescue Context::InvalidKey, Meta::NotExists => e
      @logger.error "Invalid path"
    rescue OCIError => e
      @logger.error e.parse_error_offset ? "#{e.message} at #{e.parse_error_offset}" : e.message
    rescue Interrupt
      @logger.warn "Interrupted by user"
    end

    # Returns new context relative to current one, traversing given path
    def context_for(path, default = nil)
      return default.dup if !path || path == ''
      new_context = @context.dup
      nodes = path.split(/[\.\/]/).collect(&:upcase) rescue []
      return new_context.root if nodes.empty?
      level = nodes[0] == '' ? nil : new_context.level

      nodes.each_with_index do |node, i|
        case
          when i.zero? && node == '' then new_context.root
          when i.zero? && node == '~' then new_context.set(schema: @user)
          when node == '-' then new_context.up
          when node == '--' then new_context.up.up
          when node =~ /^-+$/ then new_context.up.up.up
          else
            raise Context::InvalidKey if node !~ /^[a-zA-Z0-9_\$]{,30}$/
            case new_context.level
              when nil
                @meta.find(new_context.traverse(schema: node))
              when :schema
                o = @meta.find_object(new_context.schema, node)
                new_context.traverse(object: node, object_type: o.type)
              when :object
                @meta.find(new_context.traverse(column: node))
                #TODO: Subprograms
              else raise Context::InvalidKey
            end
        end
      end
      new_context
    end

    # Gets SYS password either from orapass file or user input, then spawns subshell
    def su(command = nil)
      su_credentials = Credentials.new('sys', nil, @database).fill_password_from_vault
      su_credentials.password = ask("SYS password: ") { |q| q.echo = '' } if !su_credentials.password
      App.new(su_credentials, :SYSDBA, @logger, @context.su('SYS')).run(command)
    end
  end
end
