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

    # @return [Boolean] A boolean indicating whether the next item is the first
    #   in its namespace. This is used to determine whether to insert a blank
    #   line before it or not.
    attr_accessor :next_item_is_first_in_namespace

    # Create a new RBI generator.
    # @param [Hash] options
    # @option options [Integer] break_params
    # @option options [Boolean] replace_errors_with_untyped
    # @option options [Boolean] replace_unresolved_with_untyped
    # @option options [Boolean] comments
    # @return [void]
    def initialize(options)
      @rbi_contents = ['# typed: strong']
      @namespace_count = 0
      @method_count = 0
      @break_params = options[:break_params]
      @replace_errors_with_untyped = options[:replace_errors_with_untyped]
      @replace_unresolved_with_untyped = options[:replace_unresolved_with_untyped]
      @warnings = []
      @next_item_is_first_in_namespace = true

      # Hook the logger so that messages are added as comments to the RBI file
      Logging.add_hook do |type, msg, item, indent_level = 0|
        rbi_contents << "#{'  ' * (indent_level + 1)}# sord #{type} - #{msg}"
      end if options[:comments]

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

    # Adds a single blank line to the RBI file, unless this item is the first
    # in its namespace.
    # @return [void]
    def add_blank
      rbi_contents << '' unless next_item_is_first_in_namespace
      self.next_item_is_first_in_namespace = false
    end

    # Given a YARD CodeObject, add lines defining its mixins (that is, extends
    # and includes) to the current RBI file. Returns the number of mixins.
    # @param [YARD::CodeObjects::Base] item
    # @param [Integer] indent_level
    # @return [Integer]
    def add_mixins(item, indent_level)
      includes = item.instance_mixins
      extends = item.class_mixins

      extends.reverse_each do |this_extend|
        rbi_contents << "#{'  ' * (indent_level + 1)}extend #{this_extend.path}"
      end
      includes.reverse_each do |this_include|
        rbi_contents << "#{'  ' * (indent_level + 1)}include #{this_include.path}"
      end

      extends.length + includes.length
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
          terminator = params.length - 1 == i ? '' : ','
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
      item.meths.each do |meth|
        count_method

        # If the method is an alias, skip it so we don't define it as a
        # separate method. Sorbet will handle it automatically.
        if meth.is_alias?
          next
        end

        add_blank

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
            .find { |p| p.name&.gsub('*', '') == name.gsub('*', '') }]
        end.to_h

        sig_params_list = parameter_names_to_tags.map do |name, tag|
          name = name.gsub('*', '')

          if tag
            "#{name}: #{TypeConverter.yard_to_sorbet(tag.types, meth, indent_level, @replace_errors_with_untyped, @replace_unresolved_with_untyped)}"
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
              "#{param.name.gsub('*', '')}: #{TypeConverter.yard_to_sorbet(param.types, meth, indent_level, @replace_errors_with_untyped, @replace_unresolved_with_untyped)}" unless param.name.nil?
            end.join(', ')
            return_string = TypeConverter.yard_to_sorbet(yieldreturn, meth, indent_level, @replace_errors_with_untyped, @replace_unresolved_with_untyped)

            # Create proc types, if possible
            if yieldparams.empty? && yieldreturn.nil?
              "#{name}: T.untyped"
            elsif yieldreturn.nil?
              "#{name}: T.proc#{params_string.empty? ? '' : ".params(#{params_string})"}.void"
            else
              "#{name}: T.proc#{params_string.empty? ? '' : ".params(#{params_string})"}.returns(#{return_string})"
            end
          elsif meth.path.end_with? '='
            # Look for the matching getter method
            getter_path = meth.path[0...-1]
            getter = item.meths.find { |m| m.path == getter_path }

            unless getter
              if parameter_names_to_tags.length == 1 \
                && meth.tags('param').length == 1 \
                && meth.tag('param').types
  
                Logging.infer("argument name in single @param inferred as #{parameter_names_to_tags.first.first.inspect}", meth, indent_level)
                next "#{name}: #{TypeConverter.yard_to_sorbet(meth.tag('param').types, meth, indent_level, @replace_errors_with_untyped, @replace_unresolved_with_untyped)}"
              else  
                Logging.omit("no YARD type given for #{name.inspect}, using T.untyped", meth, indent_level)
                next "#{name}: T.untyped"
              end
            end

            inferred_type = TypeConverter.yard_to_sorbet(
              getter.tags('return').flat_map(&:types), meth, indent_level, @replace_errors_with_untyped, @replace_unresolved_with_untyped)
            
            Logging.infer("inferred type of parameter #{name.inspect} as #{inferred_type} using getter's return type", meth, indent_level)
            # Get rid of : on keyword arguments.
            name = name.chop if name.end_with?(':')
            "#{name}: #{inferred_type}"
          else
            # Is this the only argument, and was a @param specified without an
            # argument name? If so, infer it
            if parameter_names_to_tags.length == 1 \
              && meth.tags('param').length == 1 \
              && meth.tag('param').types

              Logging.infer("argument name in single @param inferred as #{parameter_names_to_tags.first.first.inspect}", meth, indent_level)
              "#{name}: #{TypeConverter.yard_to_sorbet(meth.tag('param').types, meth, indent_level, @replace_errors_with_untyped, @replace_unresolved_with_untyped)}"
            else
              Logging.omit("no YARD type given for #{name.inspect}, using T.untyped", meth, indent_level)
              # Get rid of : on keyword arguments.
              name = name.chop if name.end_with?(':')
              "#{name}: T.untyped"
            end
          end
        end

        return_tags = meth.tags('return')
        returns = if return_tags.length == 0
          Logging.omit("no YARD return type given, using T.untyped", meth, indent_level)
          "returns(T.untyped)"
        elsif return_tags.length == 1 && return_tags&.first&.types&.first&.downcase == "void"
          "void"
        else
          "returns(#{TypeConverter.yard_to_sorbet(meth.tag('return').types, meth, indent_level, @replace_errors_with_untyped, @replace_unresolved_with_untyped)})"
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
    # @return [void]
    def add_namespace(item, indent_level = 0)
      count_namespace
      add_blank

      if item.type == :class && item.superclass.to_s != "Object"
        rbi_contents << "#{'  ' * indent_level}class #{item.name} < #{item.superclass.path}" 
      else
        rbi_contents << "#{'  ' * indent_level}#{item.type} #{item.name}"
      end

      self.next_item_is_first_in_namespace = true
      if add_mixins(item, indent_level) > 0
        self.next_item_is_first_in_namespace = false
      end
      add_methods(item, indent_level)

      item.children.select { |x| [:class, :module].include?(x.type) }
        .each { |child| add_namespace(child, indent_level + 1) }

      self.next_item_is_first_in_namespace = false

      rbi_contents << "#{'  ' * indent_level}end"
    end

    # Generates the RBI file from the loading registry and returns its contents.
    # You must load a registry first!
    # @return [String]
    def generate
      # Generate top-level modules, which recurses to all modules
      YARD::Registry.root.children
        .select { |x| [:class, :module].include?(x.type) }
        .each { |child| add_namespace(child) }

      rbi_contents.join("\n")
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
