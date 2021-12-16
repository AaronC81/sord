module Sord
  class BaseGenerator
    # @return [Parlour::Generator]
    attr_accessor :parlour

    # @return [RbiGenerator::Namespace]
    attr_accessor :root

    # @return [Hash]
    attr_accessor :options

    # @param [RbiGenerator::Namespace] root
    # @param [Parlour::Generator] parlour
    # @param [Hash] options
    def initialize(root:, parlour:, options:)
      self.parlour = parlour || parlour_generator_class.new
      self.root = root || self.parlour.root
      self.options = options
    end

    # @return [Class<Parlour::Generator>]
    def parlour_generator_class
      raise NotImplementedError
    end

    # @param [String] constant_name
    # @param [YARD::CodeObjects::Base] constant
    # @yield [method]
    # @yieldparam [Parlour::TypedObject]
    def add_constants(constant_name:, constant:, &block)
      raise NotImplementedError
    end

    # @param [String] name
    # @param [Parlour::Types::Type] type
    # @param [Object] default
    # @return [Parlour::TypedObject]
    def add_parameter(name:, type:, default:)
      raise NotImplementedError
    end

    # @param [String] name
    # @param [Symbol] :accessor, :reader, :writer
    # @param [Parlour::Types::Type] type
    # @param [Symbol] :class, :instance
    # @param [YARD::CodeObjects::Base] reader_or_writer
    # @yield [method]
    # @yieldparam [Parlour::TypedObject]
    def add_attribute(name:, kind:, type:, attr_loc:, reader_or_writer:, &block)
      raise NotImplementedError
    end

    # @param [YARD::CodeObjects::ExtendedMethodObject] meth
    # @param [Array<Parlour::TypedObject>] parlour_params
    # @param [Parlour::Types::Untyped,Parlour::Types::Type] returns
    # @yield [method]
    # @yieldparam [Parlour::TypedObject]
    def add_method(meth:, parlour_params:, returns:, &block)
      raise NotImplementedError
    end

    # @param [Array<String>] constant_names
    # @param [String] constant_name
    def check_constant_valid?(constant_names:, constant_name:)
      true
    end
  end
end
