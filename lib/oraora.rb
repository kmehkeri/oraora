require 'readline'
require 'highline'
require 'highline/import'
require 'indentation'
require 'oci8'

Dir[File.dirname(__FILE__) + '/oraora/**/*.rb'].each { |file| require file }