# typed: true
require 'yard'
require 'sord/type_converter'
require 'sord/logging'
require 'parlour'
require 'rainbow'

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
    # @option options [Parlour::RbiGenerator] generator
    # @option options [Parlour::RbiGenerator::Namespace] root
    # @return [void]
    def initialize(options)
      @parlour = options[:parlour] || Parlour::RbiGenerator.new
      @current_object = options[:root] || @parlour.root

      @namespace_count = 0
      @method_count = 0
      @warnings = []

      @replace_errors_with_untyped = options[:replace_errors_with_untyped]
      @replace_unresolved_with_untyped = options[:replace_unresolved_with_untyped]

      # Hook the logger so that messages are added as comments to the RBI file
      Logging.add_hook do |type, msg, item|
        @current_object.add_comment_to_next_child("sord #{type} - #{msg}")
      end if options[:sord_comments]

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
        @current_object.create_include(i.path.to_s)
      end
      item.class_mixins.reverse_each do |e|
        @current_object.create_extend(e.path.to_s)
      end

      item.instance_mixins.length + item.class_mixins.length
    end

    # Given a YARD NamespaceObject, add lines defining constants.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @return [void]
    def add_constants(item)
      item.constants.each do |constant|
        # Take a constant (like "A::B::CONSTANT"), split it on each '::', and
        # set the constant name to the last string in the array.
        constant_name = constant.to_s.split('::').last
        
        # Add the constant to the current object being generated.
        @current_object.create_constant(constant_name, value: "T.let(#{constant.value}, T.untyped)") do |c|
          c.add_comments(constant.docstring.all.split("\n"))
        end
      end
    end

    # Given a YARD NamespaceObject, add lines defining its methods and their
    # signatures to the current RBI file.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @return [void]
    def add_methods(item)
      item.meths(inherited: false).each do |meth|
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
            .find { |p| p.name&.gsub('*', '')&.gsub(':', '') == name.gsub('*', '').gsub(':', '') }]
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

            return_types = getter.tags('return').flat_map(&:types)
            unless return_types.any?
              Logging.omit("no YARD type given for #{name.inspect}, using T.untyped", meth)
              next 'T.untyped'
            end
            inferred_type = TypeConverter.yard_to_sorbet(
              return_types, meth, @replace_errors_with_untyped, @replace_unresolved_with_untyped)
            
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
            # If the default is "nil" but the type is not nilable, then it 
            # should become nilable
            # (T.untyped can include nil, so don't alter that)
            type = "T.nilable(#{type})" \
              if default == 'nil' && !type.start_with?('T.nilable') && type != 'T.untyped'
            Parlour::RbiGenerator::Parameter.new(
              name.to_s,
              type: type,
              default: default
            )
          end

        @current_object.create_method(
          meth.name.to_s, 
          parameters: parlour_params,
          returns: returns,
          class_method: meth.scope == :class
        ) do |m|
          m.add_comments(meth.docstring.all.split("\n"))
        end
      end
    end

    # Given a YARD NamespaceObject, add lines defining its mixins, methods
    # and children to the RBI file.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @return [void]
    def add_namespace(item)
      count_namespace

      superclass = nil
      superclass = item.superclass.path.to_s if item.type == :class && item.superclass.to_s != "Object"

      parent = @current_object
      @current_object = item.type == :class \
        ? parent.create_class(item.name.to_s, superclass: superclass)
        : parent.create_module(item.name.to_s)
      @current_object.add_comments(item.docstring.all.split("\n"))

      add_mixins(item)
      add_methods(item)
      add_constants(item)

      item.children.select { |x| [:class, :module].include?(x.type) }
        .each { |child| add_namespace(child) }

      @current_object = parent
    end

    # Populates the RBI generator with the contents of the YARD registry. You 
    # must load the YARD registry first!
    # @return [void]
    def populate
      # Generate top-level modules, which recurses to all modules
      YARD::Registry.root.children
        .select { |x| [:class, :module].include?(x.type) }
        .each { |child| add_namespace(child) }
      end

    # Populates the RBI generator with the contents of the YARD registry, then
    # uses the loaded Parlour::RbiGenerator to generate the RBI file. You must
    # load the YARD registry first!
    # @return [void]
    def generate
      populate
      @parlour.rbi
    end

    # Loads the YARD registry, populates the RBI file, and prints any relevant
    # final logs.
    # @return [void]
    def run
      # Get YARD ready
      YARD::Registry.load!

      # Populate the RBI
      populate

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
          puts "        (#{Rainbow(item&.path).bold}) #{msg}"
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
