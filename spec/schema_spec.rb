# frozen_string_literal: true

require 'spec_helper'
require 'plumb'

RSpec.describe Plumb::Schema do
  describe 'a schema with nested schemas' do
    subject(:schema) do
      described_class.new do |sc|
        sc.field(:title).type(Plumb::Types::String).default('Mr'.freeze)
        sc.field(:name).type(Plumb::Types::String)
        sc.field?(:age).type(Plumb::Types::Lax::Integer)
        sc.field(:friend).schema do |s|
          s.field(:name).type(Plumb::Types::String)
        end
        sc.field(:tags).array(Plumb::Types::Lax::String).default([].freeze)
        sc.field(:friends).default([].freeze).array do |f|
          f.field(:name).type(Plumb::Types::String).default('Anonymous'.freeze)
          f.field(:age).type(Plumb::Types::Lax::Integer)
        end
      end
    end

    specify 'resolves a valid data structure filling in defaults' do
      data = {
        name: 'Ismael',
        age: '42',
        friend: {
          name: 'Joe'
        }
      }
      result = schema.resolve(data)
      expect(result.success?).to be true
      expect(result.value).to eq({
                                   title: 'Mr',
                                   name: 'Ismael',
                                   age: 42,
                                   friend: {
                                     name: 'Joe'
                                   },
                                   tags: [],
                                   friends: []
                                 })
    end

    specify '#json_schema' do
      schema = described_class.new do |sc|
        sc.field(:title).type(Plumb::Types::String).default('Mr')
        sc.field?(:age).type(Plumb::Types::Integer)
        sc.field?(:foo).type(Plumb::Types::String.transform(::Integer, &:to_i))
      end
      data = schema.json_schema
      expect(data).to eq({
                           '$schema' => 'https://json-schema.org/draft-08/schema#',
                           type: 'object',
                           properties: {
                             'title' => { type: 'string', default: 'Mr' },
                             'age' => { type: 'integer' },
                             'foo' => { type: 'integer' }
                           },
                           required: %w[title]
                         })
    end

    it 'coerces a nested data structure' do
      payload = {
        name: 'Ismael',
        age: '42',
        friend: {
          name: 'Joe'
        },
        tags: [10, 'foo'],
        friends: [
          { name: 'Joan', age: 44 },
          { age: '45' }
        ]
      }

      assert_result(
        schema.resolve(payload),
        {
          title: 'Mr',
          name: 'Ismael',
          age: 42,
          friend: {
            name: 'Joe'
          },
          tags: %w[10 foo],
          friends: [
            { name: 'Joan', age: 44 },
            { name: 'Anonymous', age: 45 }
          ]
        },
        true
      )
    end

    it 'returns errors for invalid data' do
      result = schema.resolve({ friend: {} })
      expect(result.success?).to be false
      expect(result.errors[:name]).to eq('Must be a String')
      expect(result.errors[:friend][:name]).to eq('Must be a String')
    end

    specify '#fields' do
      field = schema.fields[:name]
      expect(field.key).to eq(:name)
    end
  end

  specify 'optional keys' do
    schema = described_class.new do |s|
      s.field(:name).type(Plumb::Types::String)
      s.field?(:age).type(Plumb::Types::Lax::Integer)
    end

    assert_result(schema.resolve({ name: 'Ismael', age: '42' }), { name: 'Ismael', age: 42 }, true)
    assert_result(schema.resolve({ name: 'Ismael' }), { name: 'Ismael' }, true)
  end

  specify 'reusing schemas' do
    friend_schema = described_class.new do |s|
      s.field(:name).type(Plumb::Types::String)
    end

    schema = described_class.new do |sc|
      sc.field(:title).type(Plumb::Types::String).default('Mr')
      sc.field(:name).type(Plumb::Types::String)
      sc.field?(:age).type(Plumb::Types::Lax::Integer)
      sc.field(:friend).schema friend_schema
    end

    assert_result(schema.resolve({ name: 'Ismael', age: '42', friend: { name: 'Joe' } }),
                  { title: 'Mr', name: 'Ismael', age: 42, friend: { name: 'Joe' } }, true)
  end

  specify 'array schemas with rules' do
    s1 = described_class.new do |sc|
      sc.field(:friends).array do |f|
        f.field(:name).type(Plumb::Types::String)
      end.rule(size: (1..))
    end

    result = s1.resolve(friends: [{ name: 'Joe' }])
    expect(result.success?).to be true

    result = s1.resolve(friends: [])
    expect(result.success?).to be false
  end

  specify 'merge with #+' do
    s1 = described_class.new do |sc|
      sc.field(:name).type(Plumb::Types::String)
    end
    s2 = described_class.new do |sc|
      sc.field?(:name).type(Plumb::Types::String)
      sc.field(:age).type(Plumb::Types::Integer).default(10)
    end
    s3 = s1 + s2
    assert_result(s3.resolve({}), { age: 10 }, true)
    assert_result(s3.resolve(name: 'Joe', foo: 1), { name: 'Joe', age: 10 }, true)

    s4 = s1.merge(s2)
    assert_result(s4.resolve(name: 'Joe', foo: 1), { name: 'Joe', age: 10 }, true)
  end

  specify '#merge' do
    s1 = described_class.new do |sc|
      sc.field(:name).type(Plumb::Types::String)
    end
    s2 = s1.merge do |sc|
      sc.field?(:age).type(Plumb::Types::Integer)
    end
    assert_result(s2.resolve(name: 'Joe'), { name: 'Joe' }, true)
    assert_result(s2.resolve(name: 'Joe', age: 20), { name: 'Joe', age: 20 }, true)
  end

  specify '#&' do
    s1 = described_class.new do |sc|
      sc.field(:name).type(Plumb::Types::String)
      sc.field?(:title).type(Plumb::Types::String)
      sc.field?(:age).type(Plumb::Types::Integer)
    end

    s2 = described_class.new do |sc|
      sc.field(:name).type(Plumb::Types::String)
      sc.field?(:age).type(Plumb::Types::Integer)
      sc.field?(:email).type(Plumb::Types::String)
    end

    s3 = s1 & s2
    assert_result(s3.resolve(name: 'Joe', age: 20, title: 'Mr', email: 'email@me.com'), { name: 'Joe', age: 20 }, true)
  end

  describe '#before' do
    it 'runs before schema fields' do
      populate_name = ->(result) { result.success(result.value.merge(name: 'Ismael')) }

      schema = described_class.new do |sc|
        # As block
        sc.before do |result|
          result.success(result.value.merge(title: 'Dr'))
        end
        # As callable
        sc.before populate_name

        sc.field(:title).type(Plumb::Types::String).default('Mr')
        sc.field(:name).type(Plumb::Types::String)
      end

      assert_result(schema.resolve({}), { title: 'Dr', name: 'Ismael' }, true)
    end

    it 'can halt processing' do
      schema = described_class.new do |sc|
        sc.before do |result|
          result.halt(errors: 'Halted')
        end

        sc.field(:title).type(Plumb::Types::String).default('Mr')
        sc.field(:name).type(Plumb::Types::String)
      end

      result = schema.resolve({})
      expect(result.success?).to be false
      expect(result.value).to eq({})
      expect(result.errors).to eq('Halted')
    end
  end

  describe '#after' do
    it 'runs after schema fields' do
      change_name = ->(result) { result.success(result.value.merge(name: 'Ismael')) }

      schema = described_class.new do |sc|
        # As callable
        sc.before change_name

        sc.field(:title).type(Plumb::Types::String).default('Mr')
        sc.field(:name).type(Plumb::Types::String)
      end

      assert_result(schema.resolve({ name: 'Joe' }), { title: 'Mr', name: 'Ismael' }, true)
    end

    it 'can halt processing' do
      schema = described_class.new do |sc|
        sc.before do |result|
          result.halt(errors: 'Halted')
        end

        sc.field(:title).type(Plumb::Types::String).default('Mr')
        sc.field(:name).type(Plumb::Types::String)
      end

      result = schema.resolve({})
      expect(result.success?).to be false
      expect(result.value).to eq({})
      expect(result.errors).to eq('Halted')
    end
  end

  specify 'Field#meta' do
    field = described_class::Field.new(:name).type(Plumb::Types::String).meta(foo: 1).meta(bar: 2)
    expect(field.metadata).to eq(type: ::String, foo: 1, bar: 2)
    expect(field.metadata).to eq(field.metadata)
  end

  specify 'Field#options' do
    field = described_class::Field.new(:name).type(Plumb::Types::String).options(%w[aa bb cc])
    assert_result(field.resolve('aa'), 'aa', true)
    assert_result(field.resolve('cc'), 'cc', true)
    assert_result(field.resolve('dd'), 'dd', false)
    expect(field.metadata[:included_in]).to eq(%w[aa bb cc])
  end

  specify 'Field#optional' do
    field = described_class::Field.new(:name).type(Plumb::Types::String.transform(::String) do |v|
                                                     "Hello #{v}"
                                                   end).optional
    assert_result(field.resolve('Ismael'), 'Hello Ismael', true)
    assert_result(field.resolve(nil), nil, true)
  end

  specify 'Field#present' do
    field = described_class::Field.new(:name).present
    assert_result(field.resolve('Ismael'), 'Ismael', true)
    assert_result(field.resolve(nil), nil, false)
    expect(field.resolve(nil).errors).to eq('must be present')
  end

  specify 'Field#required' do
    field = described_class::Field.new(:name).required
    assert_result(field.resolve, Plumb::Undefined, false)
    assert_result(field.resolve(nil), nil, true)
    expect(field.resolve.errors).to eq('is required')
  end

  specify 'Field#default' do
    field = described_class::Field.new(:friends).default([].freeze).array(Plumb::Types::String)
    assert_result(field.resolve(), [], true)
  end

  specify 'self-contained Array type' do
    array_type = Plumb::Types::Array[Plumb::Types::Integer | Plumb::Types::String.transform(::Integer, &:to_i)]
    schema = described_class.new do |sc|
      sc.field(:numbers).type(array_type)
    end

    assert_result(schema.resolve(numbers: [1, 2, '3']), { numbers: [1, 2, 3] }, true)
  end

  private

  def assert_result(result, value, is_success, debug: false)
    debugger if debug
    expect(result.value).to eq value
    expect(result.success?).to be is_success
  end
end