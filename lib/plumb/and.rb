# frozen_string_literal: true

require 'plumb/steppable'

module Plumb
  class And
    include Steppable

    attr_reader :left, :right

    def initialize(left, right)
      @left = left
      @right = right
      freeze
    end

    private def _inspect
      %((#{@left.inspect} >> #{@right.inspect}))
    end

    def call(result)
      result.map(@left).map(@right)
    end
  end
end