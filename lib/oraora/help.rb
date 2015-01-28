require 'oraora/completion'

module Oraora
  HELP = <<-HERE.reset_indentation
    Oraora v#{VERSION} - https://github.com/kmehkeri/oraora

    Commands reference:
      c / cd [path]-        Change context (or home schema if path not provided)
      l / ls [path]         List in path (or current context)
      d / desc / describe   Describe path (or current context)
      x / exit              Exit
      sudo [command]        Execute a single command as SYS
      su                    Spawn a subshell using SYS username
      - / -- / ---          Navigate 1/2/3 levels up
      .                     Navigate to database root
      !                     Refresh metadata
      ?                     Display this help
      SELECT ...            or any other SQL keyword - execute

    Quick templates (type then press <TAB> to expand):
      #{Completion::TEMPLATES.collect { |template, expansion| "%-3s => %s" % [template, expansion] }.join("\n      ")}
  HERE
end