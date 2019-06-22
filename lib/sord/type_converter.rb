require 'sord/logging'

module Sord
  # Contains methods to convert YARD types to Sorbet types.
  module TypeConverter
    # A regular expression which matches Ruby namespaces and identifiers. 
    # "Foo", "Foo::Bar", and "::Foo::Bar" are all matches, whereas "Foo.Bar"
    # or "Foo#bar" are not.
    SIMPLE_TYPE_REGEX =
      /(?:\:\:)?[a-zA-Z_][a-zA-Z_0-9]*(?:\:\:[a-zA-Z_][a-zA-Z_0-9]*)*/

    # A regular expression which matches a Ruby namespace immediately followed
    # by another Ruby namespace in angle brackets. This is the format usually
    # used in YARD to model generic types, such as "Array<String>",
    # "Hash<String, Symbol>", "Hash{String => Symbol}", etc.
    GENERIC_TYPE_REGEX =
      /(#{SIMPLE_TYPE_REGEX})\s*[<{]\s*(.*)\s*[>}]/

    # An array of built-in generic types supported by Sorbet.
    SORBET_SUPPORTED_GENERIC_TYPES = %w{Array Set Enumerable Enumerator Range Hash}
    SORBET_SINGLE_ARG_GENERIC_TYPES = %w{Array Set Enumerable Enumerator Range}

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

        current_bracketing_level += 1 if ['<', '{'].include?(params[character_pointer])
        # Decrease bracketing level by 1 when encountering `>` or `}`, unless
        # the previous character is `=` (to prevent hash rockets from causing
        # nesting problems).
        current_bracketing_level -= 1 if ['>', '}'].include?(params[character_pointer]) && params[character_pointer - 1] != '='

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

    # Converts a YARD type into a Sorbet type.
    # @param [Boolean, Array, String] yard The YARD type.
    # @param [YARD::CodeObjects::Base] item The CodeObject which the YARD type
    #   is associated with. This is used for logging and can be nil, but this
    #   will lead to less informative log messages.
    def self.yard_to_sorbet(yard, item=nil)
      case yard
      when nil # Type not specified
        "T.untyped"
      when  "bool", "Bool", "boolean", "Boolean", "true", "false"
        "T::Boolean"
      when 'self'
        item.parent.path
      when Array
        # If there's only one element, unwrap it, otherwise allow for a
        # selection of any of the types
        types = yard
          .reject { |x| x == 'nil' }
          .map { |x| yard_to_sorbet(x, item) }
          .uniq
        result = types.length == 1 ? types.first : "T.any(#{types.join(', ')})"
        result = "T.nilable(#{result})" if yard.include?('nil')
        result
      when /^#{SIMPLE_TYPE_REGEX}$/
        # If this doesn't begin with an uppercase letter, warn
        if /^[_a-z]/ === yard
          Logging.warn("#{yard} is probably not a type, but using anyway", item)
        end
        yard
      when /^\##{SIMPLE_TYPE_REGEX}$/
        Logging.duck("#{yard} looks like a duck type, replacing with T.untyped", item)
        'T.untyped'
      when /^#{GENERIC_TYPE_REGEX}$/
        generic_type = $1
        type_parameters = $2

        if SORBET_SUPPORTED_GENERIC_TYPES.include?(generic_type)
          parameters = split_type_parameters(type_parameters)
            .map { |x| yard_to_sorbet(x, item) }
          if SORBET_SINGLE_ARG_GENERIC_TYPES.include?(generic_type) && parameters.length > 1
            "T::#{generic_type}[T.any(#{parameters.join(', ')})]"
          else
            "T::#{generic_type}[#{parameters.join(', ')}]"
          end
        else
          Logging.warn("unsupported generic type #{generic_type.inspect} in #{yard.inspect}", item)
          "SORD_ERROR_#{generic_type.gsub(/[^0-9A-Za-z_]/i, '')}"
        end
      else
        Logging.warn("#{yard.inspect} does not appear to be a type", item)
        "SORD_ERROR_#{yard.gsub(/[^0-9A-Za-z_]/i, '')}"
      end
    end
  end
end
