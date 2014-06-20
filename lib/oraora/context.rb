module Oraora
  class Context
    class InvalidKey < StandardError; end

    HIERARCHY = {
      nil =>       [:schema],
      schema:      [:object],
      object:      [:column, :subprogram],
      column:      [],
      subprogram:  [],
    }
    KEYS = HIERARCHY.keys.compact + [:object_type, :subprogram_type]
    RELATION_OBJECT_TYPES = ['TABLE', 'VIEW', 'MATERIALIZED VIEW']

    attr_reader :level, :user, *KEYS

    def initialize(user = nil, hash = {})
      @user = user
      set(hash)
    end

    def su(user)
      self.class.new(user, key_hash)
    end

    def dup
      su(@user)
    end

    def set(hash = {})
      KEYS.each { |key| instance_variable_set("@#{key}", nil) }
      @level = nil
      traverse(hash)
    end

    def traverse(hash)
      while(!hash.empty?) do
        key = HIERARCHY[@level].detect { |k| hash[k] } or raise InvalidKey
        case key
          when :column then raise InvalidKey unless RELATION_OBJECT_TYPES.include?(@object_type)
          when :object then raise InvalidKey unless @object_type = hash.delete(:object_type)
          when :subprogram then raise InvalidKey unless @object_type == :package && @subprogram_type = hash.delete(:subprogram_type)
        end
        @level = key
        instance_variable_set("@#{key}", hash.delete(key))
      end
      self
    end

    def root
      set
    end

    def up
      case @level
        when nil then return self
        when :subprogram then @subprogram_type = nil
        when :object then @object_type = nil
      end
      instance_variable_set("@#{level}", nil)
      @level = HIERARCHY.invert.detect { |k, v| k.include? @level }.last
      self
    end

    def prompt
      if @schema
        p = @user == @schema ? '~' : @schema
        level_2 = @object
        p += ".#{level_2}" if level_2
        level_3 = @column || @subprogram
        p += ".#{level_3}" if level_3
      else
        p = '/'
      end
      p
    end

    private

    def key_hash
      Hash[ KEYS.collect { |key| [key, instance_variable_get("@#{key}")] } ].delete_if { |k, v| v.nil? }
    end
  end
end
