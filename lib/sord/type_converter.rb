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
        # e.g. Hash<Symbol => String>
        if params[character_pointer] == '=' && params[character_pointer + 1] == '>'
          if current_bracketing_level == 0
            character_pointer += 1
            result << buffer.strip
            buffer = ""
            should_buffer = false
          end
        end

        buffer += params[character_pointer] if should_buffer
        character_pointer += 1
      end

      result << buffer.strip

      result
    end

    # Converts a YARD type into a Parlour type.
    # @param [Boolean, Array, String] yard The YARD type.
    # @param [YARD::CodeObjects::Base] item The CodeObject which the YARD type
    #   is associated with. This is used for logging and can be nil, but this
    #   will lead to less informative log messages.
    # @param [Boolean] replace_errors_with_untyped If true, T.untyped is used
    #   instead of SORD_ERROR_ constants for unknown types.
    # @param [Boolean] replace_unresolved_with_untyped If true, T.untyped is used
    #   when Sord is unable to resolve a constant.
    # @return [Parlour::Types::Type]
    def self.yard_to_parlour(yard, item = nil, replace_errors_with_untyped = false, replace_unresolved_with_untyped = false)
      case yard
      when nil # Type not specified
        Parlour::Types::Untyped.new
      when  "bool", "Bool", "boolean", "Boolean", "true", "false"
        Parlour::Types::Boolean.new
      when 'self'
        Parlour::Types::Self.new
      when Array
        # If there's only one element, unwrap it, otherwise allow for a
        # selection of any of the types
        types = yard
          .reject { |x| x == 'nil' }
          .map { |x| yard_to_parlour(x, item, replace_errors_with_untyped, replace_unresolved_with_untyped) }
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
            if replace_unresolved_with_untyped
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
        Logging.duck("#{yard} looks like a duck type, replacing with untyped", item)
        Parlour::Types::Untyped.new
      when /^#{GENERIC_TYPE_REGEX}$/
        generic_type = $1
        type_parameters = $2

        # If we don't do this, `const_defined?` will resolve "::Array" as the actual Ruby `Array`
        # type, not `Parlour::Types::Array`!
        relative_generic_type = generic_type.start_with?('::') \
          ? generic_type[2..-1] : generic_type

        parameters = split_type_parameters(type_parameters)
          .map { |x| yard_to_parlour(x, item, replace_errors_with_untyped, replace_unresolved_with_untyped) }
        if SINGLE_ARG_GENERIC_TYPES.include?(relative_generic_type) && parameters.length > 1
          Parlour::Types.const_get(relative_generic_type).new(Parlour::Types::Union.new(parameters))
        elsif relative_generic_type == 'Class' && parameters.length == 1
          Parlour::Types::Class.new(parameters.first)
        elsif relative_generic_type == 'Hash'
          if parameters.length == 2
            Parlour::Types::Hash.new(*parameters)
          else
            handle_sord_error(parameters.map(&:describe).join, "Invalid hash, must have exactly two types: #{yard.inspect}.", item, replace_errors_with_untyped)
          end
        else
          if Parlour::Types.const_defined?(relative_generic_type)
            # This generic is built in to parlour, but sord doesn't
            # explicitly know about it.
            Parlour::Types.const_get(relative_generic_type).new(*parameters)
          else
            # This is a user defined generic
            Parlour::Types::Generic.new(
              yard_to_parlour(generic_type),
              parameters
            )
          end
        end
      # Converts ordered lists like Array(Symbol, String) or (Symbol, String)
      # into tuples.
      when ORDERED_LIST_REGEX
        type_parameters = $1
        parameters = split_type_parameters(type_parameters)
          .map { |x| yard_to_parlour(x, item, replace_errors_with_untyped, replace_unresolved_with_untyped) }
        Parlour::Types::Tuple.new(parameters)
      when SHORTHAND_HASH_SYNTAX
        type_parameters = $1
        parameters = split_type_parameters(type_parameters)
          .map { |x| yard_to_parlour(x, item, replace_errors_with_untyped, replace_unresolved_with_untyped) }
        # Return a warning about an invalid hash when it has more or less than two elements.
        if parameters.length == 2
          Parlour::Types::Hash.new(*parameters)
        else
          handle_sord_error(parameters.map(&:describe).join, "Invalid hash, must have exactly two types: #{yard.inspect}.", item, replace_errors_with_untyped)
        end
      when SHORTHAND_ARRAY_SYNTAX
        type_parameters = $1
        parameters = split_type_parameters(type_parameters)
          .map { |x| yard_to_parlour(x, item, replace_errors_with_untyped, replace_unresolved_with_untyped) }
        parameters.one? \
          ? Parlour::Types::Array.new(parameters.first)
          : Parlour::Types::Array.new(Parlour::Types::Union.new(parameters))
      else
        # Check for literals
        from_yaml = YAML.load(yard) rescue nil
        return Parlour::Types::Raw.new(from_yaml.class.to_s) \
          if [Symbol, Float, Integer].include?(from_yaml.class)

        return handle_sord_error(yard.to_s, "#{yard.inspect} does not appear to be a type", item, replace_errors_with_untyped)
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
  end
end
