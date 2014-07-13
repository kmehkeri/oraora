module Oraora
  class Completion
    TEMPLATES = {
        's'  => 'SELECT',
        's*' => 'SELECT * FROM',
        'i'  => 'INSERT',
        'u'  => 'UPDATE',
        'd'  => 'DELETE',
        'a'  => 'ALTER',
        'c'  => 'CREATE',
        'cr' => 'CREATE OR REPLACE'
    }
    def initialize(app)
      @app = app
    end

    def comp_proc
      Proc.new do |s|
        # Complete with template alone if matched
        if TEMPLATES[Readline.line_buffer.downcase]
          TEMPLATES[Readline.line_buffer.downcase]

        else
          # Complete for SQL keywords
          comp = App::SQL_KEYWORDS

          # Complete for current context
          if s !~ /[\.\/]/
            comp += @app.meta.find(@app.context).list rescue []
            context = @app.context.dup
            comp += @app.meta.find(context.up).list while context.level

          # Complete for input
          else
            context = @app.context.dup
            path = s.split(/(?<=[\.\/])/, -1)
            last = path.pop
            loop do
              comp_context = @app.context_for(context, path.join) rescue nil
              if comp_context
                comp += @app.meta.find(comp_context).list.collect { |n| path.join + n } rescue []
              end
              break if context.level == nil
              context.up
            end
          end

          comp.sort.uniq.grep(/^#{Regexp.escape(s)}/i)
        end
      end
    end

  end
end