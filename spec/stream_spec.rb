# frozen_string_literal: true

require 'spec_helper'
require 'plumb'

RSpec.describe Plumb::Types::Stream do
  it 'returns an Enumerator that validates each row' do
    over_tens = Types::Stream[Types::Integer[10..]]
    stream = over_tens.parse([10, 20, 3, 40])

    assert_result(stream.next, 10, true)
    assert_result(stream.next, 20, true)
    assert_result(stream.next, 3, false)
    assert_result(stream.next, 40, true)
  end

  private

  def assert_result(result, value, is_success, debug: false)
    debugger if debug
    expect(result.value).to eq value
    expect(result.valid?).to be(is_success)
  end
end
