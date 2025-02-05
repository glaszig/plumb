# frozen_string_literal: true

module Plumb
  module TypeRegistry
    def const_added(const_name)
      obj = const_get(const_name)
      case obj
      when Module
        obj.extend TypeRegistry
      when Composable
        anc = [name, const_name].join('::')
        obj.freeze.name.set(anc)
      end
    end

    def included(host)
      host.extend TypeRegistry
      constants(false).each do |const_name|
        const = const_get(const_name)
        anc = [host.name, const_name].join('::')
        case const
        when Module
          child_mod = Module.new
          child_mod.define_singleton_method(:name) do
            anc
          end
          child_mod.send(:include, const)
          host.const_set(const_name, child_mod)
        when Composable
          type = const.dup
          type.freeze.name.set(anc)
          host.const_set(const_name, type)
        end
      end
    end
  end
end
