# typed: true
require 'yard'
require 'sord/type_converter'
require 'sord/logging'
require 'parlour'
require 'rainbow'
require 'parser/current'

module Sord
  # Converts the current working directory's YARD registry into an type
  # signature file.
  class Generator
    VALID_MODES = [:rbi, :rbs]

    # @return [Integer] The number of objects this generator has processed so
    #   far.
    def object_count
      @namespace_count + @method_count
    end

    # @return [Array<Array(String, YARD::CodeObjects::Base, Integer)>] The
    #   errors encountered by by the generator. Each element is of the form
    #   [message, item, line].
    attr_reader :warnings

    # Create a new generator.
    # @param [Hash] options
    # @option options [Symbol] mode
    # @option options [Integer] break_params
    # @option options [Boolean] replace_errors_with_untyped
    # @option options [Boolean] replace_unresolved_with_untyped
    # @option options [Boolean] hide_private
    # @option options [Boolean] comments
    # @option options [Parlour::Generator] generator
    # @option options [Parlour::TypedObject] root
    # @return [void]
    def initialize(options)
      @mode = options[:mode].to_sym rescue options[:mode]
      raise "invalid mode #{@mode}, expected one of: #{VALID_MODES.join(', ')}" \
        unless VALID_MODES.include?(@mode)

      @parlour = options[:parlour] || \
        case @mode
        when :rbi
          Parlour::RbiGenerator.new
        when :rbs
          Parlour::RbsGenerator.new
        end
      @current_object = options[:root] || @parlour.root

      @namespace_count = 0
      @method_count = 0
      @warnings = []

      @replace_errors_with_untyped = options[:replace_errors_with_untyped]
      @replace_unresolved_with_untyped = options[:replace_unresolved_with_untyped]
      @keep_original_comments = options[:keep_original_comments]
      @hide_private = options[:hide_private]
      @skip_constants = options[:skip_constants]
      @use_original_initialize_return = options[:use_original_initialize_return]
      @exclude_untyped = options[:exclude_untyped]

      @type_converter_config = TypeConverter::Configuration.new(
        output_language: @mode,
        replace_errors_with_untyped: @replace_errors_with_untyped,
        replace_unresolved_with_untyped: @replace_unresolved_with_untyped,
      )

      # Hook the logger so that messages are added as comments
      Logging.add_hook do |type, msg, item, **opts|
        # Hack: the "exclude untyped" log message needs to print somewhere, but
        # if there's no future object for that comment to associate with, it'll
        # never be printed!
        # Instead, add an arbitrary containing the comment
        if opts[:immediate]
          @current_object.create_arbitrary(code: "# sord #{type} - #{msg}")
        else
          @current_object.add_comment_to_next_child("sord #{type} - #{msg}")
        end
      end if options[:sord_comments]

      # Hook the logger so that warnings are collected
      Logging.add_hook do |type, msg, item|
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
    # and includes) to the current file. Returns the number of mixins.
    # @param [YARD::CodeObjects::Base] item
    # @return [Integer]
    def add_mixins(item)
      item.instance_mixins.reverse_each do |i|
        @current_object.create_include(i.path.to_s)
      end

      # YARD 0.9.26 makes extends appear in the same order as code
      # (includes are still reversed)
      if Gem::Version.new(YARD::VERSION) >= Gem::Version.new("0.9.26")
        item.class_mixins.each do |e|
          @current_object.create_extend(e.path.to_s)
        end
      else
        item.class_mixins.reverse_each do |e|
          @current_object.create_extend(e.path.to_s)
        end
      end

      item.instance_mixins.length + item.class_mixins.length
    end

    # Given a YARD NamespaceObject, add lines defining constants.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @return [void]
    def add_constants(item)
      inserted_constant_names = Set.new

      item.constants(included: false).each do |constant|
        next if @hide_private && constant.visibility == :private
        # Take a constant (like "A::B::CONSTANT"), split it on each '::', and
        # set the constant name to the last string in the array.
        constant_name = constant.to_s.split('::').last
        if inserted_constant_names.include?(constant_name) && @mode == :rbs
          Logging.warn("RBS doesn't support duplicate constants, but '#{constant_name}' was duplicated - dropping future occurences", constant)
          next
        end
        inserted_constant_names << constant_name

        # Add the constant to the current object being generated.
        case @mode
        when :rbi
          # Parse so we can set up constant with correct heredoc syntax
          kwargs = {}

          value = constant.value
          begin
            value_node = Parser::CurrentRuby.parse(constant.value)
            loc = value_node.loc
            if loc.instance_of? Parser::Source::Map::Heredoc
              #
              # heredocs in Ruby come after the full expression is complete.  e.g.,
              # puts(>>FOO)
              #   bar
              # FOO
              #
              # so if we want to wrap them in a T.let, we need to parse out the expression vs the rest
              kwargs[:heredocs] = constant.value[loc.heredoc_body.begin_pos...loc.heredoc_end.end_pos]
              expression = loc.expression
              value = constant.value[expression.begin_pos...expression.end_pos]
            end

          rescue Parser::SyntaxError => e
            # Emit a warning, since this may cause a syntax error when parsing the RBI
            Logging.warn("syntax error on constant value: #{e}", constant)
          end

          @current_object.create_constant(constant_name, value: "T.let(#{value}, T.untyped)", **kwargs) do |c|
            c.add_comments(constant.docstring.all.split("\n"))
          end
        when :rbs
          return_tags = constant.tags('return')
          returns = if return_tags.empty?
            Logging.omit("no YARD return type given, using untyped", constant)
            Parlour::Types::Untyped.new
          else
            TypeConverter.yard_to_parlour(
              return_tags.map(&:types).flatten,
              constant,
              @type_converter_config,
            )
          end
          @current_object.create_constant(constant_name, type: returns) do |c|
            c.add_comments(constant.docstring.all.split("\n"))
          end
        end
      end
    end

    # Adds comments to an object based on a docstring.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @param [Parlour::TypedObject] typed_object
    # @return [void]
    def add_comments(item, typed_object)
      if @keep_original_comments
        typed_object.add_comments(item.docstring.all.split("\n"))
      else
        parser = YARD::Docstring.parser
        parser.parse(item.docstring.all)

        docs_array = parser.text.split("\n")

        # Add @param tags if there are any with names and descriptions.
        params = parser.tags.select { |tag| tag.tag_name == 'param' && tag.is_a?(YARD::Tags::Tag) && !tag.name.nil? }
        # Add a blank line if there's anything before the params.
        docs_array << '' if docs_array.length.positive? && params.length.positive?
        params.each do |param|
          docs_array << '' if docs_array.last != '' && docs_array.length.positive?
          # Output params in the form of:
          # _@param_ `foo` — Lorem ipsum.
          # _@param_ `foo`
          if param.text.nil? || param.text == ''
            docs_array << "_@param_ `#{param.name}`"
          else
            docs_array << "_@param_ `#{param.name}` — #{param.text.gsub("\n", " ")}"
          end
        end

        # Add @return tags (there could possibly be more than one, despite this not being supported)
        returns = parser.tags.select { |tag| tag.tag_name == 'return' && tag.is_a?(YARD::Tags::Tag) && !tag.text.nil? && tag.text.strip != '' }
        # Add a blank line if there's anything before the returns.
        docs_array << '' if docs_array.length.positive? && returns.length.positive?
        returns.each do |retn|
          docs_array << '' if docs_array.last != '' && docs_array.length.positive?
          # Output returns in the form of:
          # _@return_ — Lorem ipsum.
          docs_array << "_@return_ — #{retn.text}"
        end

        # Iterate through the @example tags for a given YARD doc and output them in Markdown codeblocks.
        examples = parser.tags.select { |tag| tag.tag_name == 'example' && tag.is_a?(YARD::Tags::Tag) }
        examples.each do |example|
          # Only add a blank line if there's anything before the example.
          docs_array << '' if docs_array.length.positive?
          # Include the example's 'name' if there is one.
          docs_array << example.name unless example.name.nil? || example.name == ""
          docs_array << "```ruby"
          docs_array.concat(example.text.split("\n"))
          docs_array << "```"
        end if examples.length.positive?

        # Add @note and @deprecated tags.
        notice_tags = parser.tags.select { |tag| ['note', 'deprecated'].include?(tag.tag_name) && tag.is_a?(YARD::Tags::Tag) }
        # Add a blank line if there's anything before the params.
        docs_array << '' if docs_array.last != '' && docs_array.length.positive? && notice_tags.length.positive?
        notice_tags.each do |notice_tag|
          docs_array << '' if docs_array.last != ''
          # Output note/deprecated/see in the form of:
          # _@note_ — Lorem ipsum.
          # _@note_
          if notice_tag.text.nil?
            docs_array << "_@#{notice_tag.tag_name}_"
          else
            docs_array << "_@#{notice_tag.tag_name}_ — #{notice_tag.text}"
          end
        end

        # Add @see tags.
        see_tags = parser.tags.select { |tag| tag.tag_name == 'see' && tag.is_a?(YARD::Tags::Tag) }
        # Add a blank line if there's anything before the params.
        docs_array << '' if docs_array.last != '' && docs_array.length.positive? && see_tags.length.positive?
        see_tags.each do |see_tag|
          docs_array << '' if docs_array.last != ''
          # Output note/deprecated/see in the form of:
          # _@see_ `B` — Lorem ipsum.
          # _@see_ `B`
          if see_tag.text.nil?
            docs_array << "_@see_ `#{see_tag.name}`"
          else
            docs_array << "_@see_ `#{see_tag.name}` — #{see_tag.text}"
          end
        end

        # fix: yard text may contains multiple line. should deal \n.
        # else generate text will be multiple line and only first line is commented
        docs_array = docs_array.flat_map {|line| line.empty? ? [""] : line.split("\n")}
        typed_object.add_comments(docs_array)
      end
    end

    # @param method [YARD::CodeObjects::MethodObject]
    # @param tag_name [String]
    # @return [Array<YARD::Tags::Tag>]
    def method_tags(method, tag_name)
      tags = method.tags(tag_name)
      return tags if tags.any? || method.overridden_method.nil?

      method.overridden_method.tags(tag_name)
    end

    # @param method [YARD::CodeObjects::MethodObject]
    # @param tag_name [String]
    # @return [YARD::Tags::Tag, nil]
    def method_tag(method, tag_name)
      tag = method.tag(tag_name)
      return tag if tag || method.overridden_method.nil?

      method.overridden_method.tag(tag_name)
    end

    # Given a YARD NamespaceObject, add lines defining its methods and their
    # signatures to the current file.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @return [void]
    def add_methods(item)
      item.meths(inherited: false).each do |meth|
        next if @hide_private && meth.visibility == :private
        count_method

        # If the method is an alias, skip it so we don't define it as a
        # separate method.
        if meth.is_alias?
          next
        end

        # If the method is an attribute, it'll be handled by add_attributes
        if meth.is_attribute?
          next
        end

        # If the method has YARD's "@overload" tags, the information of the
        # first one is merged into meth object
        # NOTE: This code does not handle the second and subsequent @overload tags
        if meth.tag("overload")
          meth.parameters = meth.tag("overload").parameters
          meth.tag("overload").tags.each { |tag| meth.add_tag(tag) }
          meth.docstring += meth.tag("overload").docstring
        end
        
        # Sort parameters
        meth.parameters.reverse.sort! { |pair1, pair2| sort_params(pair1, pair2) }

        # This is better than iterating over YARD's "@param" tags directly
        # because it includes parameters without documentation
        # (The gsubs allow for better splat-argument compatibility)
        parameter_names_and_defaults_to_tags = meth.parameters.map do |name, default|
          [[name, fix_default_if_unary_minus(default)], method_tags(meth, 'param')
            .find { |p| p.name&.gsub('*', '')&.gsub(':', '') == name.gsub('*', '').gsub(':', '') }]
        end.to_h

        # Add block param if there is no named param but YARD tags are present
        if !parameter_names_and_defaults_to_tags.any? { |((name, _), _)| name.start_with? '&' } \
            && (method_tags(meth, 'yieldparam').any? || method_tag(meth, 'yieldreturn'))
          parameter_names_and_defaults_to_tags[['&blk']] = nil
        end

        parameter_types = parameter_names_and_defaults_to_tags.map do |name_and_default, tag|
          name = name_and_default.first

          if tag
            TypeConverter.yard_to_parlour(tag.types, meth, @type_converter_config)
          elsif name.start_with? '&'
            # Find yieldparams and yieldreturn
            yieldparams = method_tags(meth, 'yieldparam')
            yieldreturn = method_tag(meth, 'yieldreturn')&.types
            yieldreturn = nil if yieldreturn&.length == 1 &&
              yieldreturn&.first&.downcase == 'void'

            # Create strings
            params = yieldparams.map.with_index do |param, i|
              Parlour::Types::Proc::Parameter.new(
                param.name&.gsub('*', '') || "arg#{i}",
                TypeConverter.yard_to_parlour(param.types, meth, @type_converter_config)
              )
            end
            returns = TypeConverter.yard_to_parlour(yieldreturn, meth, @type_converter_config)

            # Create proc types, if possible
            if yieldparams.empty? && yieldreturn.nil?
              Parlour::Types::Untyped.new
            else
              Parlour::Types::Proc.new(params, yieldreturn.nil? ? nil : returns)
            end
          elsif meth.path.end_with? '='
            # Look for the matching getter method
            getter_path = meth.path[0...-1]
            getter = item.meths.find { |m| m.path == getter_path }

            unless getter
              if parameter_names_and_defaults_to_tags.length == 1 \
                && method_tags(meth, 'param').length == 1 \
                && method_tag(meth, 'param').types

                Logging.infer("argument name in single @param inferred as #{parameter_names_and_defaults_to_tags.first.first.first.inspect}", meth)
                next TypeConverter.yard_to_parlour(method_tag(meth, 'param').types, meth, @type_converter_config)
              else
                Logging.omit("no YARD type given for #{name.inspect}, using untyped", meth)
                next Parlour::Types::Untyped.new
              end
            end

            return_types = method_tags(getter, 'return').flat_map(&:types)
            unless return_types.any?
              Logging.omit("no YARD type given for #{name.inspect}, using untyped", meth)
              next Parlour::Types::Untyped.new
            end
            inferred_type = TypeConverter.yard_to_parlour(
              return_types, meth, @type_converter_config)

            Logging.infer("inferred type of parameter #{name.inspect} as #{inferred_type.describe} using getter's return type", meth)
            inferred_type
          else
            # Is this the only argument, and was a @param specified without an
            # argument name? If so, infer it
            if parameter_names_and_defaults_to_tags.length == 1 \
              && method_tags(meth, 'param').length == 1 \
              && method_tag(meth, 'param').types

              Logging.infer("argument name in single @param inferred as #{parameter_names_and_defaults_to_tags.first.first.first.inspect}", meth)
              TypeConverter.yard_to_parlour(method_tag(meth, 'param').types, meth, @type_converter_config)
            else
              Logging.omit("no YARD type given for #{name.inspect}, using untyped", meth)
              Parlour::Types::Untyped.new
            end
          end
        end

        return_tags = method_tags(meth, 'return')
        returns = if meth.name == :initialize && !@use_original_initialize_return
          nil
        elsif return_tags.length == 0
          Logging.omit("no YARD return type given, using untyped", meth)
          Parlour::Types::Untyped.new
        elsif return_tags.length == 1 && %w{void nil}.include?(return_tags&.first&.types&.first&.downcase)
          nil
        else
          TypeConverter.yard_to_parlour(method_tag(meth, 'return').types, meth, @type_converter_config)
        end

        rbs_block = nil
        parlour_params = parameter_names_and_defaults_to_tags
          .zip(parameter_types)
          .map do |((name, default), _), type|
            # If the default is "nil" but the type is not nilable, then it
            # should become nilable
            # (T.untyped can include nil, so don't alter that)
            type = Parlour::Types::Nilable.new(type) \
              if default == 'nil' && !type.is_a?(Parlour::Types::Nilable) && !type.is_a?(Parlour::Types::Untyped)

            case @mode
            when :rbi
              Parlour::RbiGenerator::Parameter.new(
                name.to_s,
                type: type,
                default: default
              )
            when :rbs
              if name.start_with?('&')
                rbs_block = type
                nil
              else
                Parlour::RbsGenerator::Parameter.new(
                  name.to_s,
                  type: type,
                  required: default.nil?
                )
              end
            end
          end
          .compact

        if @exclude_untyped && parlour_params.all? { |p| p.type.is_a?(Parlour::Types::Untyped) } && returns.is_a?(Parlour::Types::Untyped)
          Logging.omit("excluding untyped", meth, immediate: true)
          next
        end

        case @mode
        when :rbi
          @current_object.create_method(
            meth.name.to_s,
            parameters: parlour_params,
            returns: returns,
            class_method: meth.scope == :class
          ) do |m|
            add_comments(meth, m)
          end
        when :rbs
          @current_object.create_method(
            meth.name.to_s,
            [Parlour::RbsGenerator::MethodSignature.new(
              parlour_params, returns, block: rbs_block && !rbs_block.is_a?(Parlour::Types::Untyped) \
                ? Parlour::RbsGenerator::Block.new(rbs_block, false)
                : nil
            )],
            class_method: meth.scope == :class
          ) do |m|
            add_comments(meth, m)
          end
        end
      end
    end

    # Given a YARD NamespaceObject, add lines defining either its class
    # and instance attributes and their signatures to the current file.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @return [void]
    def add_attributes(item)
      [:class, :instance].each do |attr_loc|
        # Grab attributes for the current location (class or instance)
        attrs = item.attributes[attr_loc]
        attrs.each do |name, attribute|
          reader = attribute[:read]
          writer = attribute[:write]

          unless reader || writer
            Logging.warn("attribute is not readable or writable somehow, skipping", attribute)
            next
          end

          # Get all given types
          yard_types = []
          if reader
            next if @hide_private && reader.visibility == :private
            yard_types += reader.tags('return').flat_map(&:types).compact.reject { |x| x.downcase == 'void' } +
              reader.tags('param').flat_map(&:types)
          end
          if writer
            next if @hide_private && writer.visibility == :private
            yard_types += writer.tags('return').flat_map(&:types).compact.reject { |x| x.downcase == 'void' } +
              writer.tags('param').flat_map(&:types)
          end

          # Use untyped if not types specified anywhere, otherwise try to
          # compute Parlour type given all these types
          if yard_types.empty?
            Logging.omit("no YARD type given for #{name.inspect}, using untyped", reader || writer)
            parlour_type = Parlour::Types::Untyped.new
          elsif yard_types.all? { |x| x == 'nil' }
            # Nil attributes are extremely unusual, so just use untyped
            parlour_type = Parlour::Types::Untyped.new
          else
            parlour_type = TypeConverter.yard_to_parlour(
              yard_types, reader || writer, @type_converter_config)
          end

          # Generate attribute
          if reader && writer
            kind = :accessor
          elsif reader
            kind = :reader
          elsif writer
            kind = :writer
          end

          if @exclude_untyped && parlour_type.is_a?(Parlour::Types::Untyped)
            Logging.omit("excluding untyped attribute", reader || writer, immediate: true)
            next
          end

          case @mode
          when :rbi
            @current_object.create_attribute(
              name.to_s,
              kind: kind,
              type: parlour_type,
              class_attribute: (attr_loc == :class)
            ) do |m|
              add_comments(reader || writer, m)
            end
          when :rbs
            if attr_loc == :class
              # RBS doesn't support class attr_accessors so create individual methods

              if reader
                @current_object.create_method(
                  name.to_s,
                  [Parlour::RbsGenerator::MethodSignature.new([], parlour_type)],
                  class_method: true
                ) do |m|
                  add_comments(reader, m)
                end
              end

              if writer
                @current_object.create_method(
                  "#{name}=",
                  [Parlour::RbsGenerator::MethodSignature.new([Parlour::RbsGenerator::Parameter.new(
                    "value",
                    type: parlour_type,
                    required: true
                  )], parlour_type)],
                  class_method: true
                ) do |m|
                  add_comments(writer, m)
                end
              end
            else
              @current_object.create_attribute(
                name.to_s,
                kind: kind,
                type: parlour_type,
              ) do |m|
                add_comments(reader || writer, m)
              end
            end
          end
        end
      end
    end

    # Given a YARD NamespaceObject, add lines defining its mixins, methods
    # and children to the file.
    # @param [YARD::CodeObjects::NamespaceObject] item
    # @return [void]
    def add_namespace(item)
      return if @hide_private && item.visibility == :private
      count_namespace

      if item.type == :class && item.superclass.to_s != "Object"
        prefix = "::" if item.name.to_s == item.superclass.path
        superclass = "#{prefix}#{item.superclass.path}"
      end

      parent = @current_object
      @current_object = item.type == :class \
        ? parent.create_class(item.name.to_s, superclass: superclass)
        : parent.create_module(item.name.to_s)
      @current_object.add_comments(item.docstring.all.split("\n"))

      add_mixins(item)
      add_methods(item)
      add_attributes(item)
      add_constants(item) unless @skip_constants

      item.children.select { |x| [:class, :module].include?(x.type) }
        .each { |child| add_namespace(child) }

      @current_object = parent
    end

    # Populates the generator with the contents of the YARD registry. You
    # must load the YARD registry first!
    # @return [void]
    def populate
      # Generate top-level modules, which recurses to all modules
      YARD::Registry.root.children
        .select { |x| [:class, :module].include?(x.type) }
        .each { |child| add_namespace(child) }
      end

    # Populates the generator with the contents of the YARD registry, then
    # uses the loaded Parlour::Generator to generate the file. You must
    # load the YARD registry first!
    # @return [void]
    def generate
      populate
      @parlour.send(@mode)
    end

    # Loads the YARD registry, populates the file, and prints any relevant
    # final logs.
    # @return [void]
    def run
      # Get YARD ready
      YARD::Registry.load!

      # Populate the type information file
      populate

      if object_count.zero?
        Logging.warn("No objects processed.")
        Logging.warn("Have you definitely generated the YARD documentation for this project?")
        Logging.warn("Run `yard` to generate docs.")
      end

      Logging.done("Processed #{object_count} objects (#{@namespace_count} namespaces and #{@method_count} methods)")

      Logging.hooks.clear

      unless warnings.empty?
        Logging.warn("There were #{warnings.length} important warnings in the output file, listed below.")
        if @replace_errors_with_untyped
          Logging.warn("The types which caused them have been replaced with untyped.")
        else
          Logging.warn("The types which caused them have been replaced with SORD_ERROR_ constants.")
        end
        Logging.warn("Please edit the file to fix these errors.")
        Logging.warn("Alternatively, edit your YARD documentation so that your types are valid and re-run Sord.")
        warnings.each do |(msg, item, _)|
          message = if item
                      (filename, line), = item.files
                      "        #{Rainbow("(#{item.path}) #{filename}:#{line}:").bold} #{msg}"
                    else
                      "        #{msg}"
                   end
          puts message
        end
      end
    rescue
      Logging.error("An internal error occurred while running Sord: #{$!}")
      raise
    end

    # Given two pairs of arrays representing method parameters, in the form
    # of ["variable_name", "default_value"], sort the parameters so they're
    # valid for Sorbet. Sorbet requires that, e.g. required kwargs go before
    # optional kwargs.
    #
    # @param [Array] pair1
    # @param [Array] pair2
    # @return Integer
    def sort_params(pair1, pair2)
      pair1_type, pair2_type = [pair1, pair2].map do |pair|
        if pair[0].start_with?('&')
          :blk
        elsif pair[0].start_with?('**')
          :doublesplat
        elsif pair[0].start_with?('*')
          :splat
        elsif !pair[0].end_with?(':') && pair[1].nil?
          :required_ordered_param
        elsif !pair[0].end_with?(':') && !pair[1].nil?
          :optional_ordered_param
        elsif pair[0].end_with?(':') && pair[1].nil?
          :required_kwarg
        elsif pair[0].end_with?(':') && !pair[1].nil?
          :optional_kwarg
        end
      end

      pair_type_order = {
        required_ordered_param: 1,
        optional_ordered_param: 2,
        splat: 3,
        required_kwarg: 4,
        optional_kwarg: 5,
        doublesplat: 6,
        blk: 7
      }

      return pair_type_order[pair1_type] <=> pair_type_order[pair2_type]
    end

    # Removes the last character of a default parameter value if it begins with
    # '-', working around a bug in YARD. (See lsegal/yard #894)
    #
    # @param [String] default
    # @return [String, nil]
    def fix_default_if_unary_minus(default)
      if default.nil?
        nil
      elsif default[0] == '-' && !default.start_with?('->')
        default[0..-2]
      else
        default
      end
    end
  end
end
