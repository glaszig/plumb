# frozen_string_literal: true

require 'plumb/steppable'

module Plumb
  class AnyClass
    include Steppable

    def |(other) = Steppable.wrap(other)
    def >>(other) = Steppable.wrap(other)

    # Any.default(value) must trigger default when value is Undefined
    def default(...)
      Types::Undefined.not.default(...)
    end

    def call(result) = result
  end
end
