# typed: true
require 'yaml'
require 'sord/logging'
require 'sord/resolver'
require 'parlour'

module Sord
  # Contains methods to convert YARD types to Parlour types.
  module TypeConverter
    # A regular expression which matches Ruby namespaces and identifiers.
    # "Foo", "Foo::Bar", and "::Foo::Bar" are all matches, whereas "Foo.Bar"
    # or "Foo#bar" are not.
    SIMPLE_TYPE_REGEX =
      /(?:\:\:)?[a-zA-Z_][\w]*(?:\:\:[a-zA-Z_][\w]*)*/

    # A regular expression which matches a Ruby namespace immediately followed
    # by another Ruby namespace in angle brackets or curly braces.
    # This is the format usually used in YARD to model generic
    # types, such as "Array<String>", "Hash<String, Symbol>",
    # "Hash{String => Symbol}", etc.
    GENERIC_TYPE_REGEX =
      /(#{SIMPLE_TYPE_REGEX})\s*[<{]\s*(.*)\s*[>}]/

    # Matches valid method names.
    # From: https://stackoverflow.com/a/4379197/2626000
    METHOD_NAME_REGEX =
      /(?:[a-z_]\w*[?!=]?|\[\]=?|<<|>>|\*\*|[!~+\*\/%&^|-]|[<>]=?|<=>|={2,3}|![=~]|=~)/i

    # Match duck types which require the object implement one or more methods,
    # like '#foo', '#foo & #bar', '#foo&#bar&#baz', and '#foo&#bar&#baz&#foo_bar'.
    DUCK_TYPE_REGEX =
      /^\##{METHOD_NAME_REGEX}(?:\s*\&\s*\##{METHOD_NAME_REGEX})*$/

    # A regular expression which matches ordered lists in the format of
    # either "Array(String, Symbol)" or "(String, Symbol)".
    ORDERED_LIST_REGEX = /^(?:Array|)\((.*)\s*\)$/

    # A regular expression which matches the shorthand Hash syntax,
    # "{String => Symbol}".
    SHORTHAND_HASH_SYNTAX = /^{\s*(.*)\s*}$/

    # A regular expression which matches the shorthand Array syntax,
    # "<String>".
    SHORTHAND_ARRAY_SYNTAX = /^<\s*(.*)\s*>$/

    # Built in parlour single arg generics
    SINGLE_ARG_GENERIC_TYPES = %w{Array Set Enumerable Enumerator Range}

    # Given a string of YARD type parameters (without angle brackets), splits
    # the string into an array of each type parameter.
    # @param [String] params The type parameters.
    # @return [Array<String>] The split type parameters.
    def self.split_type_parameters(params)
      result = []
      buffer = ""
      current_bracketing_level = 0
      character_pointer = 0

      while character_pointer < params.length
        should_buffer = true

        current_bracketing_level += 1 if ['<', '{', '('].include?(params[character_pointer])
        # Decrease bracketing level by 1 when encountering `>` or `}`, unless
        # the previous character is `=` (to prevent hash rockets from causing
        # nesting problems).
        current_bracketing_level -= 1 if ['>', '}', ')'].include?(params[character_pointer]) && params[character_pointer - 1] != '='

        # Handle commas as separators.
        # e.g. Hash<Symbol, String>
        if params[character_pointer] == ','
          if current_bracketing_level == 0
            result << buffer.strip
            buffer = ""
            should_buffer = false
          end
        end

        # Handle hash rockets as separators.
        # e.g. Hash<Symbol => String> or Hash<Symbol, String => Integer>
        if params[character_pointer] == '=' && params[character_pointer + 1] == '>'
          if current_bracketing_level == 0
            character_pointer += 1
            result << buffer.strip
            buffer = ""
            # commas are higher precedence
            result = [result] if result.length > 1
            return [result.first, split_type_parameters(params[character_pointer+1..-1].strip)]
          end
        end

        buffer += params[character_pointer] if should_buffer
        character_pointer += 1
      end

      result << buffer.strip

      result
    end

    # Configuration for how the type converter should work in particular cases.
    class Configuration
      def initialize(replace_errors_with_untyped:, replace_unresolved_with_untyped:, output_language:)
        @output_language = output_language
        @replace_errors_with_untyped = replace_errors_with_untyped
        @replace_unresolved_with_untyped = replace_unresolved_with_untyped
      end

      # The language which the generated types will be converted to - one of
      # `:rbi` or `:rbs`.
      attr_accessor :output_language

      # @return [Boolean] If true, T.untyped is used instead of SORD_ERROR_
      #   constants for unknown types.
      attr_accessor :replace_errors_with_untyped

      # @param [Boolean] replace_unresolved_with_untyped If true, T.untyped is
      #   used when Sord is unable to resolve a constant.
      attr_accessor :replace_unresolved_with_untyped
    end

    # Converts a YARD type into a Parlour type.
    # @param [Boolean, Array, String] yard The YARD type.
    # @param [YARD::CodeObjects::Base] item The CodeObject which the YARD type
    #   is associated with. This is used for logging and can be nil, but this
    #   will lead to less informative log messages.
    # @param [Configuration] config The generation configuration.
    # @return [Parlour::Types::Type]
    def self.yard_to_parlour(yard, item, config)
      case yard
      when nil # Type not specified
        Parlour::Types::Untyped.new
      when "nil"
        Parlour::Types::Raw.new('NilClass')
      when  "bool", "Bool", "boolean", "Boolean", "true", "false"
        Parlour::Types::Boolean.new
      when "undefined" # solargraph convention
        Parlour::Types::Untyped.new
      when 'self'
        Parlour::Types::Self.new
      when Array
        # If there's only one element, unwrap it, otherwise allow for a
        # selection of any of the types
        types = yard
          .reject { |x| x == 'nil' }
          .map { |x| yard_to_parlour(x, item, config) }
          .uniq(&:hash)
        result = types.length == 1 \
          ? types.first
          : Parlour::Types::Union.new(types)
        result = Parlour::Types::Nilable.new(result) if yard.include?('nil')
        result
      when /^#{SIMPLE_TYPE_REGEX}$/
        if SINGLE_ARG_GENERIC_TYPES.include?(yard)
          return Parlour::Types.const_get(yard).new(Parlour::Types::Untyped.new)
        elsif yard == "Hash"
          return Parlour::Types::Hash.new(
            Parlour::Types::Untyped.new, Parlour::Types::Untyped.new
          )
        end
        # If this doesn't begin with an uppercase letter, warn
        if /^[_a-z]/ === yard
          Logging.warn("#{yard} is probably not a type, but using anyway", item)
        end

        # Check if whatever has been specified is actually resolvable; if not,
        # do some inference to replace it
        if item && !Resolver.resolvable?(yard, item)
          if Resolver.path_for(yard)
            new_path = Resolver.path_for(yard)
            Logging.infer("#{yard} was resolved to #{new_path}", item) \
              unless yard == new_path
            Parlour::Types::Raw.new(new_path)
          else
            if config.replace_unresolved_with_untyped
              Logging.warn("#{yard} wasn't able to be resolved to a constant in this project, replaced with untyped", item)
              Parlour::Types::Untyped.new
            else
              Logging.warn("#{yard} wasn't able to be resolved to a constant in this project", item)
              Parlour::Types::Raw.new(yard)
            end
          end
        else
          Parlour::Types::Raw.new(yard)
        end
      when DUCK_TYPE_REGEX
        if config.output_language == :rbs && (type = duck_type_to_rbs_type(yard))
          Logging.duck("#{yard} looks like a duck type with an equivalent RBS interface, replacing with #{type.generate_rbs}", item)
          type
        else
          Logging.duck("#{yard} looks like a duck type, replacing with untyped", item)
          Parlour::Types::Untyped.new
        end
      when /^#{GENERIC_TYPE_REGEX}$/
        generic_type = $1
        type_parameters = $2

        # If we don't do this, `const_defined?` will resolve "::Array" as the actual Ruby `Array`
        # type, not `Parlour::Types::Array`!
        relative_generic_type = generic_type.start_with?('::') \
          ? generic_type[2..-1] : generic_type

        yard_parameters = split_type_parameters(type_parameters)
        parameters = yard_parameters
          .map { |x| yard_to_parlour(x, item, config) }
        if SINGLE_ARG_GENERIC_TYPES.include?(relative_generic_type) && yard_parameters.length > 1
          Parlour::Types.const_get(relative_generic_type).new(yard_to_parlour(yard_parameters, item, config))
        elsif relative_generic_type == 'Class'
          if parameters.length == 1
            Parlour::Types::Class.new(parameters.first)
          else
            Parlour::Types::Union.new(parameters.map { |x| Parlour::Types::Class.new(x) })
          end
        elsif relative_generic_type == 'Hash'
          if parameters.length == 2
            Parlour::Types::Hash.new(*parameters)
          else
            handle_sord_error(parameters.map(&:describe).join, "Invalid hash, must have exactly two types: #{yard.inspect}.", item, config.replace_errors_with_untyped)
          end
        else
          if Parlour::Types.constants.include?(relative_generic_type.to_sym)
            # This generic is built in to parlour, but sord doesn't
            # explicitly know about it.
            Parlour::Types.const_get(relative_generic_type).new(*parameters)
          else
            # This is a user defined generic
            Parlour::Types::Generic.new(
              yard_to_parlour(generic_type, nil, config),
              parameters
            )
          end
        end
      # Converts ordered lists like Array(Symbol, String) or (Symbol, String)
      # into tuples.
      when ORDERED_LIST_REGEX
        type_parameters = $1
        parameters = split_type_parameters(type_parameters)
          .map { |x| yard_to_parlour(x, item, config) }
        Parlour::Types::Tuple.new(parameters)
      when SHORTHAND_HASH_SYNTAX
        type_parameters = $1
        parameters = split_type_parameters(type_parameters)
          .map { |x| yard_to_parlour(x, item, config) }
        # Return a warning about an invalid hash when it has more or less than two elements.
        if parameters.length == 2
          Parlour::Types::Hash.new(*parameters)
        else
          handle_sord_error(parameters.map(&:describe).join, "Invalid hash, must have exactly two types: #{yard.inspect}.", item, config.replace_errors_with_untyped)
        end
      when SHORTHAND_ARRAY_SYNTAX
        type_parameters = $1
        parameters = split_type_parameters(type_parameters)
          .map { |x| yard_to_parlour(x, item, config) }
        parameters.one? \
          ? Parlour::Types::Array.new(parameters.first)
          : Parlour::Types::Array.new(Parlour::Types::Union.new(parameters))
      else
        # Check for literals
        from_yaml = YAML.load(yard) rescue nil
        return Parlour::Types::Raw.new(from_yaml.class.to_s) \
          if [Symbol, Float, Integer].include?(from_yaml.class)

        return handle_sord_error(yard.to_s, "#{yard.inspect} does not appear to be a type", item, config.replace_errors_with_untyped)
      end
    end

    # Handles SORD_ERRORs.
    #
    # @param [String, Parlour::Types::Type] name
    # @param [String] log_warning
    # @param [YARD::CodeObjects::Base] item
    # @param [Boolean] replace_errors_with_untyped
    # @return [Parlour::Types::Type]
    def self.handle_sord_error(name, log_warning, item, replace_errors_with_untyped)
      Logging.warn(log_warning, item)
      str = name.is_a?(Parlour::Types::Type) ? name.describe : name
      return replace_errors_with_untyped \
        ? Parlour::Types::Untyped.new
        : Parlour::Types::Raw.new("SORD_ERROR_#{name.gsub(/[^0-9A-Za-z_]/i, '')}")
    end

    # Taken from: https://github.com/ruby/rbs/blob/master/core/builtin.rbs
    # When the latest commit was: 6c847d1
    #
    # Interfaces which use generic arguments have those arguments as `untyped`, since I'm not aware
    # of any standard way that these are specified.
    DUCK_TYPES_TO_RBS_TYPE_NAMES = {
      # Concrete
      "#to_i" => "_ToI",
      "#to_int" => "_ToInt",
      "#to_r" => "_ToR",
      "#to_s" => "_ToS",
      "#to_str" => "_ToStr",
      "#to_proc" => "_ToProc",
      "#to_path" => "_ToPath",
      "#read" => "_Reader",
      "#readpartial" => "_ReaderPartial",
      "#write" => "_Writer",
      "#rewind" => "_Rewindable",
      "#to_io" => "_ToIO",
      "#exception" => "_Exception",

      # Generic - these will be put in a `Types::Raw`, so writing RBS syntax is a little devious,
      # but by their nature we know they'll only be used in an RBS file, so it's probably fine
      "#to_hash" => "_ToHash[untyped, untyped]",
      "#each" => "_Each[untyped]",
    }

    # Given a YARD duck type string, attempts to convert it to one of a list of pre-defined RBS
    # built-in interfaces.
    #
    # For example, the common duck type `#to_s` has a built-in RBS equivalent `_ToS`.
    #
    # If no such interface exists, returns `nil`.
    #
    # @param [String] type
    # @return [Parlour::Types::Type, nil]
    def self.duck_type_to_rbs_type(type)
      type_name = DUCK_TYPES_TO_RBS_TYPE_NAMES[type]
      if !type_name.nil?
        Parlour::Types::Raw.new(type_name)
      else
        nil
      end
    end
  end
end
