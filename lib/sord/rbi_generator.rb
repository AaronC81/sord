# typed: true
require 'yard'
require 'sord/type_converter'
require 'colorize'
require 'sord/logging'

module Sord
  # Converts the current working directory's YARD registry into an RBI file.
  class RbiGenerator
    # @return [Array<String>] The lines of the generated RBI file so far.
    attr_reader :rbi_contents
    
    # @return [Integer] The number of objects this generator has processed so 
    #   far.
    attr_reader :object_count

    # Create a new RBI generator.
    # @return [RbiGenerator]
    def initialize
      @rbi_contents = ['# typed: strong']
      @object_count = 0

      # Hook the logger so that messages are added as comments to the RBI file
      Logging.add_hook do |type, msg, item|
        rbi_contents << "  # sord #{type} - #{msg}"
      end
    end

    # Increment the object counter.
    # @return [void]
    def count_object
      @object_count += 1
    end

    # Given a YARD CodeObject, add lines defining its mixins (that is, extends
    # and includes) to the current RBI file.
    # @param [YARD::CodeObjects::Base] item
    # @return [void]
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

    # Given a YARD NamespaceObject, add lines defining its methods and their
    # signatures to the current RBI file.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @return [void]
    def add_methods(item)
      # TODO: block documentation

      item.meths.each do |meth|
        count_object

        parameter_list = meth.parameters.map do |name, default|
          "#{name}#{default && " = #{default}"}"
        end.join(", ")

        # This is better than iterating over YARD's "@param" tags directly 
        # because it includes parameters without documentation
        parameter_names_to_tags = meth.parameters.map do |name, _|
          [name, meth.tags('param').find { |p| p.name == name }]
        end.to_h

        sig_params_list = parameter_names_to_tags.map do |name, tag|
          if tag
            "#{name}: #{TypeConverter.yard_to_sorbet(tag.types, meth)}"
          elsif name.start_with? '*'
            # TODO: is there a YARD definition for this?
            "args: T::Array[T.any]"
          elsif meth.path.end_with? '='
            # Look for the matching getter method
            getter_path = meth.path[0...-1]
            getter = item.meths.find { |m| m.path == getter_path }

            unless getter
              Logging.omit("no YARD type given for #{name.inspect}, using T.untyped", meth)
              next "#{name}: T.untyped"
            end

            inferred_type = TypeConverter.yard_to_sorbet(
              getter.tags('return').flat_map(&:types), meth)
            
            Logging.infer("inferred type of parameter #{name.inspect} as #{inferred_type} using getter's return type", meth)
            "#{name}: #{inferred_type}"
          else
            Logging.omit("no YARD type given for #{name.inspect}, using T.untyped", meth)
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

        rbi_contents << "  def #{prefix}#{meth.name}(#{parameter_list}); end"
      end
    end

    # Generates the RBI file and writes it to the given file path.
    # @param [String] filename
    # @return [void]
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
