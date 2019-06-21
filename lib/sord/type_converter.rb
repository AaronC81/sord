module Sord
  module TypeConverter
    SIMPLE_TYPE_REGEX =
      /(?:\:\:)?[a-zA-Z_][a-zA-Z_0-9]*(?:\:\:[a-zA-Z_][a-zA-Z_0-9]*)*/

    # TODO: does not support mulitple type arguments (e.g. Hash<A, B>)
    GENERIC_TYPE_REGEX =
      /(#{SIMPLE_TYPE_REGEX})<(#{SIMPLE_TYPE_REGEX})>/

    # TODO: Hash
    SORBET_SUPPORTED_GENERIC_TYPES = %w{Array Set Enumerable Enumerator Range}

    def self.yard_to_sorbet(yard, &blk)
      case yard
      when nil
        "T.untyped"
      when  "bool", "Bool", "boolean", "Boolean", ["true", "false"], ["false", "true"]
        "T::Boolean"
      when Array
        # If there's only one element, unwrap it, otherwise allow for a
        # selection of any of the types
        yard.length == 1 \
          ? yard_to_sorbet(yard.first, &blk)
          : "T.any(#{yard.map { |x| yard_to_sorbet(x, &blk) }.join(', ')})"
      when /^#{SIMPLE_TYPE_REGEX}$/
        if /^[_a-z]/ === yard
          yield "#{yard} is probably not a type, but using anyway"
        end
        yard
      when /^#{GENERIC_TYPE_REGEX}$/
        generic_type = $1
        type_parameter = $2

        if SORBET_SUPPORTED_GENERIC_TYPES.include?(generic_type)
          if /^[_a-z]/ === type_parameter
            yield "#{type_parameter} is probably not a type, but using anyway"
          end  

          "T::#{generic_type}[#{yard_to_sorbet(type_parameter, &blk)}]"
        else
          yield "unsupported generic type #{generic_type.inspect} in #{yard.inspect}"
          "SORD_ERROR_#{generic_type.gsub(/[^0-9A-Za-z_]/i, '')}"
        end
      else
        yield "#{yard.inspect} does not appear to be a type"
        "SORD_ERROR_#{yard.gsub(/[^0-9A-Za-z_]/i, '')}"
      end
    end
  end
end