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
      @oci = OCI8.new(@user, credentials.password, @database, @role)

      # Set default context
      @context = Context.new(user: @user, schema: @user)

      # TODO: Add readline completion

      # Main loop
      buffer = ''
      while (line = Readline.readline(@context.prompt).strip) do
        buffer += (buffer == '' ? '' : "\n") + line
        if (buffer == line && line =~ /^(#{ORAORA_KEYWORDS.join('|')})($|\s+)/) || line == '/' || line =~ /;$/
          process(buffer)
          buffer = ''
        end
      end

      puts "[DEBUG] Exiting on end-of-file"
      terminate

    rescue Interrupt
      puts "[DEBUG] Exiting on CTRL+C"
      terminate
    end

    def process(text)
      puts "[DEBUG] Processing: #{text}"
      # Determine first non-comment word of a command
      text =~ /\A(?:\/\*.*?\*\/\s*|--.*?\n)*\s*([^[:space:]\*\(\/;]+)?(.*)?/mi
      case first_word = $1 && $1.downcase
        # Nothing, gibberish or just comments
        when nil
          if $2
            puts "[DEBUG] Gibberish!"
          end

        # TODO: Change context
        when 'c', 'cd'
          puts "[DEBUG] Switch context"
          if !$2 || $2.strip == ''
            puts "[DEBUG] -> home"
            @context.set(schema: @user)
          else
            saved_context = @context
            begin
              path = $2.strip.split(/\s+/)[0].split(/[\.\/]/)
              puts "[DEBUG] -> #{path.inspect}"
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
                    puts "[DEBUG] Traversing: #{node}"
                    case @context.level
                      when nil then Meta.validate_schema(node) && @context.traverse(schema: node)
                      when :schema then (object_type = Meta.object_type(@context.schema, node)) && @context.traverse(object_type => node)
                      when :table, :view, :mview then Meta.validate_column(@context.schema, @context.relation, node) && @context.traverse(column: node)
                      when :package then (object_type = Meta.program_type(@context.schema, @context.package, node)) && @context.traverse(object_type => node)
                      else raise Context::InvalidKey
                    end
                end
              end
            rescue Context::InvalidKey
              puts "[DEBUG] Invalid path"
              @context = saved_context
            end
          end

        when 'l', 'ls'
          puts "[DEBUG] List objects"
          # TODO: Context/filter by argument
          # TODO: Disable terminal size check when not reading from terminal
          terminal_cols = HighLine::SystemExtensions.terminal_size[0]
          objects = @oci.describe_schema(@context[:schema]).objects.reject { |o| o =~ /\$/ }.collect(&:obj_name).sort
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
          begin
            cursor = @oci.exec(text.gsub(/[;\/]$/, ''))
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
          puts "[ERROR] Unknown command: #{$1}"
      end
    end

    # Log off the server. 
    def terminate
      puts "[DEBUG] Logging off"
      @oci.logoff
      exit
    end
  end
end
