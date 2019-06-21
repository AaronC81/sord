# typed: true
require 'yard'

module Sord
  class RbiGenerator
    attr_reader :rbi_contents

    def initialize
      @rbi_contents = []
    end

    def anyize(types)
      types.length == 1 \
        ? types.first
        : "T.any(#{types.join(', ')})"
    end

    def add_mixins(item)
      extends = item.instance_mixins
      includes = item.class_mixins

      extends.each do |this_extend|
        rbi_contents << "  extend #{this_extend.path}"
      end
      includes.each do |this_include|
        rbi_contents << "  include #{this_include.path}"
      end
    end

    def run
      # Get YARD ready
      YARD::Registry.load!

      # Populate the RBI with modules first
      YARD::Registry.all(:module).each do |item|
        rbi_contents << "module #{item.path}"

        add_mixins(item)

        rbi_contents << "end"
      end

      # Now populate with classes
      YARD::Registry.all(:class).each do |item|
        # Generate core class definition stuff
        superclass = (item.superclass if item.superclass.to_s != "Object")

        rbi_contents << "class #{item.path} #{"< #{superclass}" if superclass}" 
        
        add_mixins(item)

        # TODO: constants?
        item.meths.each do |meth|
          parameter_list = meth.parameters.map do |name, default|
            # TODO: is it possible to differentiate between no default, and the 
            # default being nil?
            "#{name} = #{default.nil? ? 'nil' : default}"
          end.join(", ")

          # TODO: This needs to be more rigid - convert Array<X> to T::Array[X], convert 'nil' in an Any to T.nilable, warn about invalid looking types and add comments above them, etc.
          params_list = meth.tags('param').map do |param|
            next "#{param.name}: T.untyped" if param.types.nil?

            type = anyize(param.types)
            "#{param.name}: #{type}"
          end.join(", ")

          case meth.tags('return').length
          when 0
            returns = "void"
          when 1
            returns = "returns(#{anyize(meth.tag('return').types)})"
          else
            returns = "returns(#{anyize(meth.tags('return').flat_map(&:types))})"
          end

          prefix = meth.scope == :class ? 'self.' : ''

          rbi_contents << "  sig { params(#{params_list}).#{returns} }"

          rbi_contents << "  def #{prefix}#{meth.name}(#{parameter_list}) end"
        end

        rbi_contents << "end"
      end

      puts rbi_contents
    end
  end
end