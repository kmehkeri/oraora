module Oraora
  class App
    class InvalidCommand < StandardError; end

    SQL_INITIAL_KEYWORDS = %w(
      SELECT COUNT FROM PARTITION WHERE CONNECT GROUP MODEL UNION INTERSECT MINUS ORDER
      INSERT UPDATE SET DELETE MERGE
      TRUNCATE ADD DROP CREATE RENAME ALTER PURGE GRANT REVOKE
      COMPILE ANALYZE COMMIT ROLLBACK
      IDENTIFIED PROFILE ACCOUNT QUOTA DEFAULT TEMPORARY
    )
    SQL_KEYWORDS = SQL_INITIAL_KEYWORDS + %w(
      TABLE VIEW MATERIALIZED COLUMN PROCEDURE FUNCTION PACKAGE TYPE BODY
      USER SESSION SCHEMA SYSTEM DATABASE
      REPLACE AND OR
    )
    ORAORA_KEYWORDS = %w(c cd l ls d desc describe x exit su sudo - -- --- . !)

    attr_reader :meta, :context

    def initialize(credentials, role, logger, context = nil)
      @credentials = credentials
      @user, @database, @role = (credentials.user ? credentials.user.upcase : nil), credentials.database, (role ? role.upcase.to_sym : nil)
      @logger = logger
    end

    # Run the application with given credentials
    def run(command = nil)
      last_interrupt = Time.now - 2

      # Connect to Oracle
      @logger.debug "Connecting: #{@credentials}" + (@role ? " as #{@role}" : '')
      logon
      @user ||= @oci.username
      @context = context || Context.new(@user, schema: @user)

      # Readline tab completion
      Readline.completion_append_character = ''
      Readline.completion_proc = Completion.new(self).comp_proc

      if command
        process(command)
      else
        # Main loop
        buffer = ''
        prompt = @context.prompt + ' ' + (@role== :SYSDBA ? '#' : '$') + ' '

        while !@terminate do
          begin
            line = Readline.readline(prompt.green.bold)
            break if !line

            line.strip!
            Readline::HISTORY << line if line != '' # Manually add to history to avoid empty lines
            buffer += (buffer == '' ? '' : "\n") + line

            # Process buffer on one of these conditions:
            # * This is first line of the buffer and is empty
            # * This is first line of the buffer and is a Oraora command
            # * Entire buffer is a comment
            # * Line is '/' or ends with ';'
            if (buffer == line && (line =~ /^(#{ORAORA_KEYWORDS.collect { |k| Regexp.escape(k) }.join('|')})($|\s+)/i || line =~ /^\s*$/)) || line == '/' || line =~ /;$/ || buffer =~ /\A\s*--/ || buffer =~ /\A\s*\/\*.*\*\/\s*\Z/m
              process(buffer)
              buffer = ''
            end

            if buffer == ''
              prompt = @context.prompt + ' ' + (@role == :SYSDBA ? '#' : '$') + ' '
            else
              prompt = @context.prompt.gsub(/./, ' ') + ' % '
            end

          rescue Interrupt
            if Time.now - last_interrupt < 2
              @logger.warn "Exit on CTRL+C, "
              terminate
            else
              @logger.warn "CTRL+C, hit again within 2 seconds to quit"
              buffer = ''
              prompt = @context.prompt + ' ' + (@role == :SYSDBA ? '#' : '$') + ' '
              last_interrupt = Time.now
            end
          end
        end

      end

      if !@terminate
        @logger.debug "Exiting on end of input"
        terminate
      end
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

    # Parse command options from arguments
    # Returns options hash and the remaining argument untouched
    def options_for(args)
      options = {}
      while (args =~ /^-[[:alnum:]]/) do
        opts, args = args.split(/\s+/, 2)
        @logger.debug "Raw options: #{opts}"
        opts.gsub(/^-/, '').split('').each do |o|
          options[o.downcase] = true
        end
      end
      @logger.debug "Options: #{options}"
      [options, args]
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

      case first_word = $1 && $1.upcase
        # Nothing, gibberish or just comments
        when nil
          if $2 && $2 != ''
            raise InvalidCommand, "Invalid command: #{$2}"
          end

        when 'C', 'CD'
          @logger.debug "Switch context"
          old_schema = @context.schema || @context.user
          if $2 && $2 != ''
            @context = context_for(@context, $2[/^\S+/])
          else
            @context.set(schema: @user)
          end
          @logger.debug "New context is #{@context.send(:key_hash)}"
          if old_schema != (@context.schema || @context.user)
            @logger.debug "Implicit ALTER SESSION SET CURRENT_SCHEMA = " + (@context.schema || @context.user)
            @oci.exec("ALTER SESSION SET CURRENT_SCHEMA = " + (@context.schema || @context.user))
          end

        when 'L', 'LS'
          @logger.debug "List"
          path = $2
          filter = $2[/[^\.\/]*(\*|\?)[^\.\/]*$/]
          path = path.chomp(filter)
          path = path.chomp('.').chomp('/') unless path =~ /[\.\/]/
          filter.upcase! if filter
          @logger.debug "Path: #{path}, Filter: #{filter}"
          work_context = context_for(@context, path[/^\S+/])
          @logger.debug "List for #{work_context.level || 'database'}"
          Terminal.puts_grid(@meta.find(work_context).list({}, filter))

        when 'D', 'DESC', 'DESCRIBE'
          @logger.debug "Describe"
          options, args = options_for($2)
          path = args.split(/\s+/).first rescue nil
          work_context = context_for(@context, path)
          @logger.debug "Describe for #{work_context.level || 'database'}"
          puts(@meta.find(work_context).describe(options))

          # TODO: For refactoring
          if work_context.level == :column && options['p']
            prof = @oci.exec <<-SQL
              SELECT value, cnt, rank
                FROM (SELECT value, cnt, row_number() over (order by cnt desc) AS rank
                        FROM (SELECT #{work_context.column} AS value, count(*) AS cnt
                                FROM #{work_context.object}
                               GROUP BY #{work_context.column}
                             )
                     )
                WHERE rank <= 20 OR value IS NULL
                ORDER BY rank
            SQL
            puts ""
            Terminal.puts_cursor(prof)
          end

        # Exit
        when 'X', 'EXIT'
          @logger.debug "Exiting on exit command"
          terminate

        # SQL
        when *SQL_INITIAL_KEYWORDS
          raw_sql = text.gsub(/[;\/]\Z/, '')
          @logger.debug "SQL: #{raw_sql}"
          context_aware_sql = Awareness.enrich(raw_sql, @context)
          @logger.debug "SQL (context-aware): #{context_aware_sql}" if context_aware_sql != raw_sql
          res = @oci.exec(context_aware_sql)

          if res.is_a? OCI8::Cursor
            Terminal.puts_cursor(res)
            @logger.info "#{res.row_count} row(s) selected"
          else
            @logger.info "#{res} row(s) affected"
          end

        when 'SU'
          @logger.debug "Command type: su"
          su

        when 'SUDO'
          @logger.debug "Command type: sudo (#{$2})"
          raise InvalidCommand, "Command required for sudo" if $2.strip == ''
          su($2)

        when '!'
          @logger.debug "Command type: metadata refresh"
          @meta.purge_cache

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
    rescue StandardError
      @logger.error "Internal error"
      @logger.debug e.backtrace
    end

    # Returns new context relative to current one, traversing given path
    def context_for(context, path)
      return context.dup if !path || path == ''
      new_context = context.dup
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
