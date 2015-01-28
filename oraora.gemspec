require './lib/oraora/version'

Gem::Specification.new do |s|
  s.name        = 'oraora'
  s.version     = Oraora::VERSION
  s.summary     = "Interactive command-line utility for Oracle"
  s.description = <<-EOS
    SQL*Plus replacement for interactive work with Oracle, with tab-completion, colored output,
    metadata navigation with context-aware SQL and more features
  EOS

  s.author      = "kmehkeri"
  s.email       = 'kmehkeri@gmail.com'
  s.homepage    = 'https://github.com/kmehkeri/oraora'
  s.license     = 'MIT'

  s.files       = `git ls-files`.split($/)
  s.executables = `git ls-files -- bin`.split($/).map { |f| File.basename(f)  }

  s.add_runtime_dependency 'highline', '~> 1'
  s.add_runtime_dependency 'ruby-oci8', '~> 2'
  s.add_runtime_dependency 'indentation', '~> 0'
  s.add_runtime_dependency 'colorize', '~> 0'
  s.add_runtime_dependency 'bigdecimal', '~> 1'

  s.add_development_dependency 'rspec', '~> 3'
end
