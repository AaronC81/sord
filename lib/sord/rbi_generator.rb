require 'sord/base_generator'

module Sord
  class RbiGenerator < BaseGenerator
    def parlour_generator_class
      Parlour::RbiGenerator
    end

    # @param [String] constant_name
    # @param [YARD::CodeObjects::Base] constant
    # @yield [method]
    # @yieldparam [Parlour::RbiGenerator::Constant]
    def add_constants(constant_name:, constant:, &block)
      root.create_constant(
        constant_name,
        value: "T.let(#{constant.value}, T.untyped)",
        &block
      )
    end

    # @param [String] name
    # @param [Parlour::Types::Type] type
    # @param [String] default
    # @return [Parlour::RbiGenerator::Parameter]
    def add_parameter(name:, type:, default:)
      Parlour::RbiGenerator::Parameter.new(name, type: type, default: default)
    end

    # @param [String] name
    # @param [Symbol] :accessor, :reader, :writer
    # @param [Parlour::Types::Type] type
    # @param [Symbol] :class, :instance
    # @param [YARD::CodeObjects::Base] reader_or_writer
    # @yield [method]
    # @yieldparam [Parlour::RbiGenerator::Attribute]
    def add_attribute(name:, kind:, type:, attr_loc:, reader_or_writer:, &block)
      root.create_attribute(
        name,
        kind: kind,
        type: type,
        class_attribute: (attr_loc == :class),
        &block
      )
    end

    # @param [YARD::CodeObjects::ExtendedMethodObject] meth
    # @param [Array<Parlour::RbiGenerator::Parameter>] parlour_params
    # @param [Parlour::Types::Untyped,Parlour::Types::Type] returns
    # @yield [method]
    # @yieldparam [Parlour::RbiGenerator::Method]
    def add_method(meth:, parlour_params:, returns:, &block)
      root.create_method(
        meth.name.to_s,
        parameters: parlour_params,
        returns: returns,
        class_method: meth.scope == :class,
         &block
      )
    end
  end
end
