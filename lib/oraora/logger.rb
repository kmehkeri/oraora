require 'logger'
require 'colorize'

module Oraora
  class Logger < ::Logger
    SEVERITY_COLORS = {
        'WARN' => :yellow,
        'ERROR' => :red,
        'INFO' => :light_black,
        'DEBUG' => :light_black
    }

    def initialize(name, log_level = ::Logger::WARN)
      super
      self.level = log_level
      self.formatter = proc { |severity, datetime, progname, msg| "[#{severity}] #{msg}\n".send(SEVERITY_COLORS[severity]) }
    end
  end
end