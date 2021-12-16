require 'sord/base_generator'

module Sord
  class RbsGenerator < BaseGenerator
    def parlour_generator_class
      Parlour::RbsGenerator
    end

    # @param [String] constant_name
    # @param [YARD::CodeObjects::Base] constant
    # @yield [method]
    # @yieldparam [Parlour::RbsGenerator::Constant]
    def add_constants(constant_name:, constant:, &block)
      return_tags = constant.tags('return')
      returns =
        if return_tags.empty?
          Logging.omit('no YARD return type given, using untyped', constant)
          Parlour::Types::Untyped.new
        else
          TypeConverter.yard_to_parlour(
            return_tags.map(&:types).flatten,
            constant,
            options[:replace_errors_with_untyped],
            options[:replace_unresolved_with_untyped]
          )
        end
      root.create_constant(constant_name, type: returns, &block)
    end

    # @param [String] name
    # @param [Parlour::Types::Type] type
    # @param [Object] default
    # @return [Parlour::RbsGenerator::Parameter, nil]
    def add_parameter(name:, type:, default:)
      if name.start_with?('&')
        @has_block = type
        nil
      else
        Parlour::RbsGenerator::Parameter.new(
          name.to_s,
          type: type,
          required: default.nil?
        )
      end
    end

    # @param [String] name
    # @param [Symbol] :accessor, :reader, :writer
    # @param [Parlour::Types::Type] type
    # @param [Symbol] :class, :instance
    # @param [YARD::CodeObjects::Base] reader_or_writer
    # @yield [method]
    # @yieldparam [Parlour::RbsGenerator::Attribute]
    def add_attribute(name:, kind:, type:, attr_loc:, reader_or_writer:, &block)
      if attr_loc == :class
        Logging.warn(
          "RBS doesn't support class attributes, dropping",
          reader_or_writer
        )
      else
        root.create_attribute(name, kind: kind, type: type, &block)
      end
    end

    # @param [YARD::CodeObjects::ExtendedMethodObject] meth
    # @param [Array<Parlour::RbiGenerator::Parameter>] parlour_params
    # @param [Parlour::Types::Untyped,Parlour::Types::Type] returns
    # @yield [method]
    # @yieldparam [Parlour::RbsGenerator::Method]
    def add_method(meth:, parlour_params:, returns:, &block)
      method_signature =
        Parlour::RbsGenerator::MethodSignature.new(
          parlour_params,
          returns,
          block:
            if @has_block && !@has_block.is_a?(Parlour::Types::Untyped)
              Parlour::RbsGenerator::Block.new(@has_block, false)
            else
              nil
            end
        )
      created_method =
        root.create_method(
          meth.name.to_s,
          [method_signature],
          class_method: meth.scope == :class,
          &block
        )
      @has_block = false
      created_method
    end

    # @param [Array<String>] constant_names
    # @param [String] constant_name
    def check_constant_valid?(constant_names:, constant_name:)
      if constant_names.include?(constant_name)
        Logging.warn(
          "RBS doesn't support duplicate constants, but '#{constant_name}' was duplicated - dropping future occurrences",
          constant
        )
        false
      else
        true
      end
    end
  end
end
