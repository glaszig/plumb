# frozen_string_literal: true

require 'plumb/steppable'

module Plumb
  class HashMap
    include Steppable

    attr_reader :key_type, :value_type

    def initialize(key_type, value_type)
      @key_type = key_type
      @value_type = value_type
      freeze
    end

    def call(result)
      failed = result.value.lazy.filter_map do |key, value|
        key_r = @key_type.resolve(key)
        value_r = @value_type.resolve(value)
        if !key_r.success?
          [:key, key, key_r]
        elsif !value_r.success?
          [:value, value, value_r]
        end
      end
      if (first = failed.next)
        field, val, halt = failed.first
        result.halt(errors: "#{field} #{val.inspect} #{halt.errors}")
      end
    rescue StopIteration
      result
    end
  end
end