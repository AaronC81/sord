# typed: true
require 'yard'
require 'sord/type_converter'
require 'colorize'
require 'sord/logging'
require 'parlour'

module Sord
  # Converts the current working directory's YARD registry into an RBI file.
  class RbiGenerator    
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
    # @option options [Integer] break_params
    # @option options [Boolean] replace_errors_with_untyped
    # @option options [Boolean] replace_unresolved_with_untyped
    # @option options [Boolean] comments
    # @return [void]
    def initialize(options)
      @namespace_count = 0
      @method_count = 0
      @break_params = options[:break_params]
      @replace_errors_with_untyped = options[:replace_errors_with_untyped]
      @parlour = Parlour::RbiGenerator.new(break_params: @break_params)
      @replace_unresolved_with_untyped = options[:replace_unresolved_with_untyped]
      @warnings = []
      @current_object = @parlour.root

      # Hook the logger so that messages are added as comments to the RBI file
      Logging.add_hook do |type, msg, item|
        @current_object.add_comment_to_next_child("sord #{type} - #{msg}")
      end if options[:comments]

      # Hook the logger so that warnings are collected
      Logging.add_hook do |type, msg, item|
        # TODO: is it possible to get line numbers here?
        warnings << [msg, item, 0] if type == :warn
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
    # and includes) to the current RBI file. Returns the number of mixins.
    # @param [YARD::CodeObjects::Base] item
    # @return [Integer]
    def add_mixins(item)
      item.instance_mixins.reverse_each do |i|
        @current_object.add_include(i.name.to_s)
      end
      item.class_mixins.reverse_each do |e|
        @current_object.add_extend(e.name.to_s)
      end

      item.instance_mixins.length + item.class_mixins.length
    end

    # Given a YARD NamespaceObject, add lines defining its methods and their
    # signatures to the current RBI file.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @return [void]
    def add_methods(item)
      item.meths.each do |meth|
        count_method

        # If the method is an alias, skip it so we don't define it as a
        # separate method. Sorbet will handle it automatically.
        if meth.is_alias?
          next
        end

        # This is better than iterating over YARD's "@param" tags directly 
        # because it includes parameters without documentation
        # (The gsubs allow for better splat-argument compatibility)
        parameter_names_and_defaults_to_tags = meth.parameters.map do |name, default|
          [[name, default], meth.tags('param')
            .find { |p| p.name&.gsub('*', '') == name.gsub('*', '') }]
        end.to_h

        parameter_types = parameter_names_and_defaults_to_tags.map do |name_and_default, tag|
          name = name_and_default.first

          if tag
            TypeConverter.yard_to_sorbet(tag.types, meth, @replace_errors_with_untyped, @replace_unresolved_with_untyped)
          elsif name.start_with? '&'
            # Find yieldparams and yieldreturn
            yieldparams = meth.tags('yieldparam')
            yieldreturn = meth.tag('yieldreturn')&.types
            yieldreturn = nil if yieldreturn&.length == 1 &&
              yieldreturn&.first&.downcase == 'void'

            # Create strings
            params_string = yieldparams.map do |param|
              "#{param.name.gsub('*', '')}: #{TypeConverter.yard_to_sorbet(param.types, meth, @replace_errors_with_untyped, @replace_unresolved_with_untyped)}" unless param.name.nil?
            end.join(', ')
            return_string = TypeConverter.yard_to_sorbet(yieldreturn, meth, @replace_errors_with_untyped, @replace_unresolved_with_untyped)

            # Create proc types, if possible
            if yieldparams.empty? && yieldreturn.nil?
              'T.untyped'
            elsif yieldreturn.nil?
              "T.proc#{params_string.empty? ? '' : ".params(#{params_string})"}.void"
            else
              "T.proc#{params_string.empty? ? '' : ".params(#{params_string})"}.returns(#{return_string})"
            end
          elsif meth.path.end_with? '='
            # Look for the matching getter method
            getter_path = meth.path[0...-1]
            getter = item.meths.find { |m| m.path == getter_path }

            unless getter
              if parameter_names_and_defaults_to_tags.length == 1 \
                && meth.tags('param').length == 1 \
                && meth.tag('param').types
  
                Logging.infer("argument name in single @param inferred as #{parameter_names_and_defaults_to_tags.first.first.first.inspect}", meth)
                next TypeConverter.yard_to_sorbet(meth.tag('param').types, meth, @replace_errors_with_untyped, @replace_unresolved_with_untyped)
              else  
                Logging.omit("no YARD type given for #{name.inspect}, using T.untyped", meth)
                next 'T.untyped'
              end
            end

            inferred_type = TypeConverter.yard_to_sorbet(
              getter.tags('return').flat_map(&:types), meth, @replace_errors_with_untyped, @replace_unresolved_with_untyped)
            
            Logging.infer("inferred type of parameter #{name.inspect} as #{inferred_type} using getter's return type", meth)
            inferred_type
          else
            # Is this the only argument, and was a @param specified without an
            # argument name? If so, infer it
            if parameter_names_and_defaults_to_tags.length == 1 \
              && meth.tags('param').length == 1 \
              && meth.tag('param').types

              Logging.infer("argument name in single @param inferred as #{parameter_names_and_defaults_to_tags.first.first.first.inspect}", meth)
              TypeConverter.yard_to_sorbet(meth.tag('param').types, meth, @replace_errors_with_untyped, @replace_unresolved_with_untyped)
            else
              Logging.omit("no YARD type given for #{name.inspect}, using T.untyped", meth)
              'T.untyped'
            end
          end
        end

        return_tags = meth.tags('return')
        returns = if return_tags.length == 0
          Logging.omit("no YARD return type given, using T.untyped", meth)
          'T.untyped'
        elsif return_tags.length == 1 && return_tags&.first&.types&.first&.downcase == "void"
          nil
        else
          TypeConverter.yard_to_sorbet(meth.tag('return').types, meth, @replace_errors_with_untyped, @replace_unresolved_with_untyped)
        end

        parlour_params = parameter_names_and_defaults_to_tags
          .zip(parameter_types)
          .map do |((name, default), _), type|
            Parlour::RbiGenerator::Parameter.new(
              name: name.to_s,
              type: type,
              default: default
            )
          end

        @current_object.create_method(
          name: meth.name.to_s, 
          parameters: parlour_params,
          returns: returns,
          class_method: meth.scope == :class
        )
      end
    end

    # Given a YARD NamespaceObject, add lines defining its mixins, methods
    # and children to the RBI file.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @return [void]
    def add_namespace(item)
      count_namespace

      superclass =
        item.type == :class && item.superclass.to_s != "Object" \
        ? item.superclass.name.to_s : nil

      parent = @current_object
      @current_object = item.type == :class \
        ? parent.create_class(name: item.name.to_s, superclass: superclass)
        : parent.create_module(name: item.name.to_s)

      add_mixins(item)
      add_methods(item)

      item.children.select { |x| [:class, :module].include?(x.type) }
        .each { |child| add_namespace(child) }

      @current_object = parent
    end

    # Generates the RBI file from the loading registry and returns its contents.
    # You must load a registry first!
    # @return [String]
    def generate
      # Generate top-level modules, which recurses to all modules
      YARD::Registry.root.children
        .select { |x| [:class, :module].include?(x.type) }
        .each { |child| add_namespace(child) }

      # Workaround for bug which will be fixed in Parlour at some point
      "# typed: strong\n" + @parlour.rbi
    end

    # Generates the RBI file and writes it to the given file path, printing a
    # summary and any warnings at the end. The registry is also loaded.
    # @param [String, nil] filename
    # @return [void]
    def run(filename)
      raise 'No filename specified' unless filename

      # Get YARD ready
      YARD::Registry.load!

      # Write the file
      File.write(filename, generate)

      if object_count.zero?
        Logging.warn("No objects processed.")
        Logging.warn("Have you definitely generated the YARD documentation for this project?")
        Logging.warn("Run `yard` to generate docs.")
      end

      Logging.done("Processed #{object_count} objects (#{@namespace_count} namespaces and #{@method_count} methods)")

      Logging.hooks.clear

      unless warnings.empty?
        Logging.warn("There were #{warnings.length} important warnings in the RBI file, listed below.")
        if @replace_errors_with_untyped
          Logging.warn("The types which caused them have been replaced with T.untyped.")
        else
          Logging.warn("The types which caused them have been replaced with SORD_ERROR_ constants.")
        end
        Logging.warn("Please edit the file to fix these errors.")
        Logging.warn("Alternatively, edit your YARD documentation so that your types are valid and re-run Sord.")
        warnings.each do |(msg, item, _)|
          puts "        (#{item&.path&.bold}) #{msg}"
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
