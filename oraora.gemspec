Gem::Specification.new do |s|
  s.name        = 'oraora'
  s.version     = '0.1.0'
  s.summary     = "Interactive command-line utility for Oracle"
  s.description = "Interactive command-line utility for Oracle"

  s.author      = "kmehkeri"
  s.email       = 'kmehkeri@gmail.com'
  s.homepage    = 'http://rubygems.org/gems/oraora'
  s.license     = 'MIT'

  s.files       = `git ls-files`.split($/)
  s.executables = `git ls-files -- bin`.split($/).map { |f| File.basename(f)  }

  s.add_runtime_dependency 'highline'
  s.add_runtime_dependency 'ruby-oci8'
  s.add_runtime_dependency 'indentation'
  s.add_runtime_dependency 'colorize'
  s.add_runtime_dependency 'bigdecimal'

  s.add_development_dependency 'rspec'
end

