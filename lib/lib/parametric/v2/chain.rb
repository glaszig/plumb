# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Chain
      include Steppable

      def initialize(left, right)
        @left = left
        @right = right
      end

      def metadata
        @left.metadata.merge(@right.metadata)
      end

      def inspect
        %((#{@left.inspect} >> #{@right.inspect}))
      end

      private def _call(result)
        result.map(@left).map(@right)
      end
    end
  end
end
