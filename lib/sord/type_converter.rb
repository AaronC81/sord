require 'sord/logging'

module Sord
  # Contains methods to convert YARD types to Sorbet types.
  module TypeConverter
    # A regular expression which matches Ruby namespaces and identifiers. 
    # "Foo", "Foo::Bar", and "::Foo::Bar" are all matches, whereas "Foo.Bar"
    # or "Foo#bar" are not.
    SIMPLE_TYPE_REGEX =
      /(?:\:\:)?[a-zA-Z_][a-zA-Z_0-9]*(?:\:\:[a-zA-Z_][a-zA-Z_0-9]*)*/

    # TODO: does not support mulitple type arguments (e.g. Hash<A, B>)
    # A regular expression which matches a Ruby namespace immediately followed
    # by another Ruby namespace in angle brackets. This is the format usually
    # used in YARD to model generic types, such as "Array<String>".
    GENERIC_TYPE_REGEX =
      /(#{SIMPLE_TYPE_REGEX})<(#{SIMPLE_TYPE_REGEX})>/

    # TODO: Hash
    # An array of built-in generic types supported by Sorbet.
    SORBET_SUPPORTED_GENERIC_TYPES = %w{Array Set Enumerable Enumerator Range}

    # Converts a YARD type into a Sorbet type.
    # @param [Boolean, Array, String] yard The YARD type.
    # @param [YARD::CodeObjects::Base] item The CodeObject which the YARD type
    #   is associated with. This is used for logging and can be nil, but this
    #   will lead to less informative log messages.
    def self.yard_to_sorbet(yard, item=nil)
      case yard
      when nil
        "T.untyped"
      when  "bool", "Bool", "boolean", "Boolean", ["true", "false"], ["false", "true"]
        "T::Boolean"
      when Array
        # If there's only one element, unwrap it, otherwise allow for a
        # selection of any of the types
        yard.length == 1 \
          ? yard_to_sorbet(yard.first, item)
          : "T.any(#{yard.map { |x| yard_to_sorbet(x, item) }.join(', ')})"
      when /^#{SIMPLE_TYPE_REGEX}$/
        # If this doesn't begin with an uppercase letter, warn
        if /^[_a-z]/ === yard
          Logging.warn("#{yard} is probably not a type, but using anyway", item)
        end
        yard
      when /^#{GENERIC_TYPE_REGEX}$/
        generic_type = $1
        type_parameter = $2

        if SORBET_SUPPORTED_GENERIC_TYPES.include?(generic_type)
          if /^[_a-z]/ === type_parameter
            Logging.warn("#{type_parameter} is probably not a type, but using anyway", item)
          end  

          "T::#{generic_type}[#{yard_to_sorbet(type_parameter, item)}]"
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