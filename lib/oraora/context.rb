module Oraora
  class Context
    class InvalidKey < StandardError; end

    HIERARCHY = {
      nil =>     [:schema],
      schema:    [:table, :view, :mview, :package, :procedure, :function],
      table:     [:column],
      view:      [:column],
      mview:     [:column],
      column:    [],
      package:   [],
      procedure: [],
      function:  []
    }
    KEYS = HIERARCHY.keys.compact

    attr_reader :level, :user, *KEYS

    def initialize(hash = {})
      set(hash)
    end

    def dup
      self.class.new(key_hash.merge(user: @user))
    end

    def set(hash = {})
      KEYS.each { |key| instance_variable_set("@#{key}", nil) }
      @level = nil
      @user = hash.delete(:user) if hash[:user]
      traverse(hash)
    end

    def traverse(hash)
      while(!hash.empty?) do
        key = HIERARCHY[@level].detect { |k| hash[k] }
        raise InvalidKey if !key
        @level = key
        instance_variable_set("@#{key}", hash.delete(key))
      end
      self
    end

    def root
      set
    end

    def up
      if @level
        instance_variable_set("@#{level}", nil)
        set(key_hash)
      end
      self
    end

    def relation
      @table || @view || @mview
    end

    def prompt
      p = ''
      if @schema
        p += @user == @schema ? '~' : @schema
        level_2 = @table || @view || @mview || @package || @procedure || @function
        p += ".#{level_2}" if level_2
        level_3 = @column
        p += ".#{level_3}" if level_3
      end
      p
    end

    private

    def key_hash
      Hash[ KEYS.collect { |key| [key, instance_variable_get("@#{key}")] } ].delete_if { |k, v| v.nil? }
    end
  end
end
