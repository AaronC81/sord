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
    def object_count
      @namespace_count + @method_count
    end

    # @return [Array<Array(String, YARD::CodeObjects::Base, Integer)>] The 
    #   errors encountered by by the generator. Each element is of the form
    #   [message, item, line].
    attr_reader :warnings

    # Create a new RBI generator.
    # @param [Hash] options
    # @return [RbiGenerator]
    def initialize(options)
      @rbi_contents = ['# typed: strong']
      @namespace_count = 0
      @method_count = 0
      @break_params = options.break_params
      @warnings = []

      # Hook the logger so that messages are added as comments to the RBI file
      Logging.add_hook do |type, msg, item, indent_level = 0|
        rbi_contents << "#{'  ' * (indent_level + 1)}# sord #{type} - #{msg}"
      end if options.comments

      # Hook the logger so that warnings are collected
      Logging.add_hook do |type, msg, item, indent_level = 0|
        warnings << [msg, item, rbi_contents.length] \
          if type == :warn
      end
    end

    # Increment the namespace counter.
    # @return [void]
    def count_namespace
      @namespace_count += 1
    end

    # Increment the method counter.
    # @return [void]
    def count_method
      @method_count += 1
    end

    # Given a YARD CodeObject, add lines defining its mixins (that is, extends
    # and includes) to the current RBI file.
    # @param [YARD::CodeObjects::Base] item
    # @param [Integer] indent_level
    # @return [void]
    def add_mixins(item, indent_level)
      extends = item.instance_mixins
      includes = item.class_mixins

      extends.each do |this_extend|
        rbi_contents << "#{'  ' * (indent_level + 1)}extend #{this_extend.path}"
      end
      includes.each do |this_include|
        rbi_contents << "#{'  ' * (indent_level + 1)}include #{this_include.path}"
      end
    end

    # Given an array of parameters and a return type, inserts the signature for
    # a method with those properties into the current RBI file.
    # @param [Array<String>] params
    # @param [String] returns
    # @param [Integer] indent_level
    # @return [void]
    def add_signature(params, returns, indent_level)
      if params.empty?
        rbi_contents << "#{'  ' * (indent_level + 1)}sig { #{returns} }"
        return
      end

      if params.length >= @break_params
        rbi_contents << "#{'  ' * (indent_level + 1)}sig do"
        rbi_contents << "#{'  ' * (indent_level + 2)}params("
        params.each.with_index do |param, i|
          terminator = params.length - 1 == i ? '' : ', '
          rbi_contents << "#{'  ' * (indent_level + 3)}#{param}#{terminator}"
        end
        rbi_contents << "#{'  ' * (indent_level + 2)}).#{returns}"
        rbi_contents << "#{'  ' * (indent_level + 1)}end"
      else
        rbi_contents << "#{'  ' * (indent_level + 1)}sig { params(#{params.join(', ')}).#{returns} }"
      end
    end

    # Given a YARD NamespaceObject, add lines defining its methods and their
    # signatures to the current RBI file.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @param [Integer] indent_level
    # @return [void]
    def add_methods(item, indent_level)
      # TODO: block documentation

      item.meths.each do |meth|
        count_method

        # If the method is an alias, skip it so we don't define it as a
        # separate method. Sorbet will handle it automatically.
        if meth.is_alias?
          next
        end

        parameter_list = meth.parameters.map do |name, default|
          # Handle these three main cases:
          # - def method(param) or def method(param:)
          # - def method(param: 'default')
          # - def method(param = 'default')
          if default.nil?
            "#{name}"
          elsif !default.nil? && name.end_with?(':')
            "#{name} #{default}"
          else
            "#{name} = #{default}"
          end
        end.join(", ")

        # This is better than iterating over YARD's "@param" tags directly 
        # because it includes parameters without documentation
        # (The gsubs allow for better splat-argument compatibility)
        parameter_names_to_tags = meth.parameters.map do |name, _|
          [name, meth.tags('param')
            .find { |p| p.name.gsub('*', '') == name.gsub('*', '') }]
        end.to_h

        sig_params_list = parameter_names_to_tags.map do |name, tag|
          name = name.gsub('*', '')

          if tag
            "#{name}: #{TypeConverter.yard_to_sorbet(tag.types, meth)}"
          elsif name.start_with? '&'
            # Cut the ampersand from the block parameter name
            name = name.gsub('&', '')

            # Find yieldparams and yieldreturn
            yieldparams = meth.tags('yieldparam')
            yieldreturn = meth.tag('yieldreturn')&.types
            yieldreturn = nil if yieldreturn&.length == 1 &&
              yieldreturn&.first&.downcase == 'void'

            # Create strings
            params_string = yieldparams.map do |param|
              "#{param.name.gsub('*', '')}: #{TypeConverter.yard_to_sorbet(param.types, meth)}"
            end.join(', ')
            return_string = TypeConverter.yard_to_sorbet(yieldreturn, meth)

            # Create proc types, if possible
            if yieldparams.empty? && yieldreturn.nil?
              "#{name}: T.untyped"
            else
              "#{name}: T.proc#{params_string.empty? ? '' : ".params(#{params_string})"}.returns(#{return_string})"
            end
          elsif meth.path.end_with? '='
            # Look for the matching getter method
            getter_path = meth.path[0...-1]
            getter = item.meths.find { |m| m.path == getter_path }

            unless getter
              Logging.omit("no YARD type given for #{name.inspect}, using T.untyped", meth, indent_level)
              next "#{name}: T.untyped"
            end

            inferred_type = TypeConverter.yard_to_sorbet(
              getter.tags('return').flat_map(&:types), meth)
            
            Logging.infer("inferred type of parameter #{name.inspect} as #{inferred_type} using getter's return type", meth, indent_level)
            # Get rid of : on keyword arguments.
            name = name.chop if name.end_with?(':')
            "#{name}: #{inferred_type}"
          else
            Logging.omit("no YARD type given for #{name.inspect}, using T.untyped", meth, indent_level)
            # Get rid of : on keyword arguments.
            name = name.chop if name.end_with?(':')
            "#{name}: T.untyped"
          end
        end

        return_tags = meth.tags('return')
        returns = if return_tags.length == 0
          "void"
        elsif return_tags.length == 1 && return_tags&.first&.types&.first&.downcase == "void"
          "void"
        else
          "returns(#{TypeConverter.yard_to_sorbet(meth.tag('return').types, meth)})"
        end

        prefix = meth.scope == :class ? 'self.' : ''

        add_signature(sig_params_list, returns, indent_level)

        rbi_contents << "#{'  ' * (indent_level + 1)}def #{prefix}#{meth.name}(#{parameter_list}); end"
      end
    end

    # Given a YARD NamespaceObject, add lines defining its mixins, methods
    # and children to the RBI file.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @param [Integer] indent_level
    def add_namespace(item, indent_level = 0)
      count_namespace

      if item.type == :class && item.superclass.to_s != "Object"
        rbi_contents << "#{'  ' * indent_level}class #{item.name} < #{item.superclass.path}" 
      else
        rbi_contents << "#{'  ' * indent_level}#{item.type} #{item.name}"
      end
      add_mixins(item, indent_level)
      add_methods(item, indent_level)

      item.children.select { |x| [:class, :module].include?(x.type) }
        .each { |child| add_namespace(child, indent_level + 1) }

      rbi_contents << "#{'  ' * indent_level}end"
    end

    # Generates the RBI file and writes it to the given file path.
    # @param [String] filename
    # @return [void]
    def run(filename)
      raise "No filename specified" unless filename

      # Get YARD ready
      YARD::Registry.load!

      # TODO: constants?

      # Generate top-level modules, which recurses to all modules
      YARD::Registry.root.children
        .select { |x| [:class, :module].include?(x.type) }
        .each { |child| add_namespace(child) }

      # Write the file
      File.write(filename, rbi_contents.join(?\n))

      if object_count.zero?
        Logging.warn("No objects processed.")
        Logging.warn("Have you definitely generated the YARD documentation for this project?")
        Logging.warn("Run `yard` to generate docs.")
      end

      Logging.done("Processed #{object_count} objects (#{@namespace_count} namespaces and #{@method_count} methods)")

      Logging.hooks.clear

      unless warnings.empty?
        Logging.warn("There were #{warnings.length} important warnings in the RBI file, listed below.")
        Logging.warn("The types which caused them have been replaced with SORD_ERROR_ constants.")
        Logging.warn("Please edit the file near the line numbers given to fix these errors.")
        Logging.warn("Alternatively, edit your YARD documentation so that your types are valid and re-run Sord.")
        warnings.each do |(msg, item, line)|
          puts "        #{"Line #{line} |".light_black} (#{item&.path&.bold}) #{msg}"
        end
      end
    rescue
      Logging.error($!)
      $@.each do |line|
        puts "         #{line}"
      end
    end
  end
end
