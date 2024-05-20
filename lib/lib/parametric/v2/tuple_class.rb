# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class TupleClass
      include Steppable

      def initialize(*types)
        @types = types.map { |t| t.is_a?(Steppable) ? t : Types::Any.value(t) }
      end

      def of(*types)
        self.class.new(*types)
      end

      alias_method :[], :of

      def ast
        [:tuple, { type: 'array' }, @types.map(&:ast)]
      end

      def inspect
        "#{name}[#{@types.map(&:inspect).join(', ')}]"
      end

      private def _call(result)
        return result.halt(error: 'must be an Array') unless result.value.is_a?(::Array)
        return result.halt(error: 'must have the same size') unless result.value.size == @types.size

        errors = {}
        values = @types.map.with_index do |type, idx|
          val = result.value[idx]
          r = type.call(val)
          errors[idx] = ["expected #{type.inspect}, got #{val.inspect}", r.error].flatten unless r.success?
          r.value
        end

        return result.success(values) unless errors.any?

        result.halt(error: errors)
      end
    end
  end
end