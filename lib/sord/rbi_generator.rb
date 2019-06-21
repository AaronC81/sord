# typed: true
require 'yard'
require 'sord/type_converter'
require 'colorize'
require 'sord/logging'

module Sord
  class RbiGenerator
    attr_reader :rbi_contents, :object_count

    def initialize
      @rbi_contents = ['# typed: true']
      @object_count = 0

      Logging.add_hook do |type, msg, item|
        rbi_contents << "  # sord #{type} - #{msg}"
      end
    end

    def count_object
      @object_count += 1
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

    def add_methods(item)
      # TODO: block documentation
      item.meths.each do |meth|
        count_object

        parameter_list = meth.parameters.map do |name, default|
          "#{name}#{default && " = #{default}"}"
        end.join(", ")

        parameter_names_to_tags = meth.parameters.map do |name, _|
          [name, meth.tags('param').find { |p| p.name == name }]
        end.to_h

        # TODO: if it's a _= method, infer from the _ method
        sig_params_list = parameter_names_to_tags.map do |name, tag|
          if tag
            "#{name}: #{TypeConverter.yard_to_sorbet(tag.types, meth)}"
          elsif name.start_with? '*'
            # TODO: is there a YARD definition for this?
            "args: T::Array[T.any]"
          else
            Logging.infer("no YARD type given for #{name.inspect}, using T.untyped", meth)
            "#{name}: T.untyped"
          end
        end.join(", ")

        return_tags = meth.tags('return')
        returns = if return_tags.length == 0
          "void"
        elsif return_tags.length == 1 && return_tags.first.types.first.downcase == "void"
          "void"
        else
          "returns(#{TypeConverter.yard_to_sorbet(meth.tag('return').types, meth)})"
        end

        prefix = meth.scope == :class ? 'self.' : ''

        rbi_contents << "  sig { params(#{sig_params_list}).#{returns} }"

        rbi_contents << "  def #{prefix}#{meth.name}(#{parameter_list}) end"
      end
    end

    def run(filename)
      # Get YARD ready
      YARD::Registry.load!

      # TODO: constants?

      # Populate the RBI with modules first
      YARD::Registry.all(:module).each do |item|
        count_object
        
        rbi_contents << "module #{item.path}"
        add_mixins(item)
        add_methods(item)
        rbi_contents << "end"
      end

      # Now populate with classes
      YARD::Registry.all(:class).each do |item|
        count_object

        superclass = (item.superclass if item.superclass.to_s != "Object")
        rbi_contents << "class #{item.path} #{"< #{superclass}" if superclass}" 
        add_mixins(item)
        add_methods(item)        
        rbi_contents << "end"
      end

      # Write the file
      raise "no filename specified" unless filename
      File.write(filename, rbi_contents.join(?\n))

      Logging.done("Processed #{object_count} objects")
    rescue
      Logging.error($!)
      $@.each do |line|
        puts "         #{line}".light_white
      end
    end
  end
end