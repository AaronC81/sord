# typed: strong

module Sord
  VERSION = T.let('3.0.1', T.untyped)

  # Handles writing logs to stdout and any other classes which request them.
  module Logging
    AVAILABLE_TYPES = T.let([:warn, :info, :duck, :error, :infer, :omit, :done].freeze, T.untyped)

    # _@return_ — The hooks registered on the logger.
    sig { returns(T::Array[Proc]) }
    def self.hooks; end

    # _@return_ — Whether log messages should be printed or not. This is
    # used for testing.
    sig { returns(T::Boolean) }
    def self.silent?; end

    # Sets whether log messages should be printed or not.
    # 
    # _@param_ `value`
    sig { params(value: T::Boolean).void }
    def self.silent=(value); end

    # Sets the array of log messages types which should be processed. Any not on
    # this list will be discarded. This should be a subset of AVAILABLE_TYPES.
    # 
    # _@param_ `value`
    sig { params(value: T::Array[Symbol]).void }
    def self.enabled_types=(value); end

    # Gets the array of log messages types which should be processed. Any not on
    # this list will be discarded.
    sig { returns(T::Array[Symbol]) }
    def self.enabled_types; end

    # Returns a boolean indicating whether a given array is a valid value for 
    # #enabled_types.
    # 
    # _@param_ `value`
    sig { params(value: T::Array[Symbol]).void }
    def self.valid_types?(value); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # A generic log message writer which is called by all other specific logging
    # methods. This shouldn't be called outside of the Logging class itself.
    # 
    # _@param_ `kind` — The kind of log message this is.
    # 
    # _@param_ `header` — The prefix for this log message. For consistency, it should be up to five uppercase characters wrapped in square brackets, with some unique colour applied.
    # 
    # _@param_ `msg` — The log message to write.
    # 
    # _@param_ `item` — The CodeObject which this log  is associated with, if any. This is shown before the log message if it is specified.
    sig do
      params(
        kind: Symbol,
        header: String,
        msg: String,
        item: YARD::CodeObjects::Base
      ).void
    end
    def self.generic(kind, header, msg, item); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # Print a warning message. This should be used for things which require the
    # user's attention but do not prevent the process from stopping.
    # 
    # _@param_ `msg` — The log message to write.
    # 
    # _@param_ `item` — The CodeObject which this log  is associated with, if any. This is shown before the log message if it is specified.
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.warn(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # Print an info message. This should be used for generic informational
    # messages which the user doesn't need to act on.
    # 
    # _@param_ `msg` — The log message to write.
    # 
    # _@param_ `item` — The CodeObject which this log  is associated with, if any. This is shown before the log message if it is specified.
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.info(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # Print a duck-typing message. This should be used when the YARD 
    # documentation contains duck typing, which isn't supported by Sorbet, so
    # it is substituted for something different.
    # 
    # _@param_ `msg` — The log message to write.
    # 
    # _@param_ `item` — The CodeObject which this log  is associated with, if any. This is shown before the log message if it is specified.
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.duck(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # Print an error message. This should be used for things which require the
    # current process to stop.
    # 
    # _@param_ `msg` — The log message to write.
    # 
    # _@param_ `item` — The CodeObject which this log  is associated with, if any. This is shown before the log message if it is specified.
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.error(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # Print an infer message. This should be used when the user should be told
    # that some information has been filled in or guessed for them, and that 
    # information is likely correct.
    # 
    # _@param_ `msg` — The log message to write.
    # 
    # _@param_ `item` — The CodeObject which this log  is associated with, if any. This is shown before the log message if it is specified.
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.infer(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # Print an omit message. This should be used as a special type of warning
    # to alert the user that there is some information missing, but this
    # information is not critical to the completion of the process.
    # 
    # _@param_ `msg` — The log message to write.
    # 
    # _@param_ `item` — The CodeObject which this log  is associated with, if any. This is shown before the log message if it is specified.
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.omit(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # Print a done message. This should be used when a process completes
    # successfully.
    # 
    # _@param_ `msg` — The log message to write.
    # 
    # _@param_ `item` — The CodeObject which this log  is associated with, if any. This is shown before the log message if it is specified.
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.done(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # Invokes all registered hooks on the logger.
    # 
    # _@param_ `kind` — The kind of log message this is.
    # 
    # _@param_ `msg` — The log message to write.
    # 
    # _@param_ `item` — The CodeObject which this log  is associated with, if any. This is shown before the log message if it is specified.
    sig { params(kind: Symbol, msg: String, item: YARD::CodeObjects::Base).void }
    def self.invoke_hooks(kind, msg, item); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # Adds a hook to the logger.
    sig { params(blk: T.proc.params(kind: Symbol, msg: String, item: YARD::CodeObjects::Base).void).void }
    def self.add_hook(&blk); end
  end

  module Resolver
    sig { void }
    def self.prepare; end

    sig { void }
    def self.clear; end

    # _@param_ `name`
    sig { params(name: String).returns(T::Array[String]) }
    def self.paths_for(name); end

    # _@param_ `name`
    sig { params(name: String).returns(T.nilable(String)) }
    def self.path_for(name); end

    sig { returns(T::Array[String]) }
    def self.builtin_classes; end

    # _@param_ `name`
    # 
    # _@param_ `item`
    sig { params(name: String, item: Object).returns(T::Boolean) }
    def self.resolvable?(name, item); end
  end

  # Converts the current working directory's YARD registry into an type
  # signature file.
  class Generator
    VALID_MODES = T.let([:rbi, :rbs], T.untyped)

    # _@return_ — The number of objects this generator has processed so 
    # far.
    sig { returns(Integer) }
    def object_count; end

    # Create a new generator.
    # 
    # _@param_ `options`
    sig { params(options: T::Hash[T.untyped, T.untyped]).void }
    def initialize(options); end

    # Increment the namespace counter.
    sig { void }
    def count_namespace; end

    # Increment the method counter.
    sig { void }
    def count_method; end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # Given a YARD CodeObject, add lines defining its mixins (that is, extends
    # and includes) to the current file. Returns the number of mixins.
    # 
    # _@param_ `item`
    sig { params(item: YARD::CodeObjects::Base).returns(Integer) }
    def add_mixins(item); end

    # sord warn - YARD::CodeObjects::NamespaceObject wasn't able to be resolved to a constant in this project
    # Given a YARD NamespaceObject, add lines defining constants.
    # 
    # _@param_ `item`
    sig { params(item: YARD::CodeObjects::NamespaceObject).void }
    def add_constants(item); end

    # sord warn - YARD::CodeObjects::NamespaceObject wasn't able to be resolved to a constant in this project
    # sord warn - Parlour::TypedObject wasn't able to be resolved to a constant in this project
    # Adds comments to an object based on a docstring.
    # 
    # _@param_ `item`
    # 
    # _@param_ `typed_object`
    sig { params(item: YARD::CodeObjects::NamespaceObject, typed_object: Parlour::TypedObject).void }
    def add_comments(item, typed_object); end

    # sord warn - YARD::CodeObjects::NamespaceObject wasn't able to be resolved to a constant in this project
    # Given a YARD NamespaceObject, add lines defining its methods and their
    # signatures to the current file.
    # 
    # _@param_ `item`
    sig { params(item: YARD::CodeObjects::NamespaceObject).void }
    def add_methods(item); end

    # sord warn - YARD::CodeObjects::NamespaceObject wasn't able to be resolved to a constant in this project
    # Given a YARD NamespaceObject, add lines defining either its class
    # and instance attributes and their signatures to the current file.
    # 
    # _@param_ `item`
    sig { params(item: YARD::CodeObjects::NamespaceObject).void }
    def add_attributes(item); end

    # sord warn - YARD::CodeObjects::NamespaceObject wasn't able to be resolved to a constant in this project
    # Given a YARD NamespaceObject, add lines defining its mixins, methods
    # and children to the file.
    # 
    # _@param_ `item`
    sig { params(item: YARD::CodeObjects::NamespaceObject).void }
    def add_namespace(item); end

    # Populates the generator with the contents of the YARD registry. You 
    # must load the YARD registry first!
    sig { void }
    def populate; end

    # Populates the generator with the contents of the YARD registry, then
    # uses the loaded Parlour::Generator to generate the file. You must
    # load the YARD registry first!
    sig { void }
    def generate; end

    # Loads the YARD registry, populates the file, and prints any relevant
    # final logs.
    sig { void }
    def run; end

    # Given two pairs of arrays representing method parameters, in the form
    # of ["variable_name", "default_value"], sort the parameters so they're
    # valid for Sorbet. Sorbet requires that, e.g. required kwargs go before
    # optional kwargs.
    # 
    # _@param_ `pair1`
    # 
    # _@param_ `pair2`
    # 
    # _@return_ — Integer
    sig { params(pair1: T::Array[T.untyped], pair2: T::Array[T.untyped]).returns(T.untyped) }
    def sort_params(pair1, pair2); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # _@return_ — The 
    # errors encountered by by the generator. Each element is of the form
    # [message, item, line].
    sig { returns(T::Array[[String, YARD::CodeObjects::Base, Integer]]) }
    attr_reader :warnings
  end

  class ParlourPlugin < Parlour::Plugin
    # sord omit - no YARD type given for "options", using untyped
    sig { params(options: T.untyped).void }
    def initialize(options); end

    # sord omit - no YARD type given for "root", using untyped
    # sord omit - no YARD return type given, using untyped
    sig { params(root: T.untyped).returns(T.untyped) }
    def generate(root); end

    # sord omit - no YARD return type given, using untyped
    sig { params(block: T.untyped).returns(T.untyped) }
    def self.with_clean_env(&block); end

    # sord omit - no YARD type given for :options, using untyped
    # Returns the value of attribute options.
    sig { returns(T.untyped) }
    attr_reader :options

    # Returns the value of attribute parlour.
    sig { returns(T.untyped) }
    attr_accessor :parlour
  end

  # Contains methods to convert YARD types to Parlour types.
  module TypeConverter
    SIMPLE_TYPE_REGEX = T.let(/(?:\:\:)?[a-zA-Z_][\w]*(?:\:\:[a-zA-Z_][\w]*)*/, T.untyped)
    GENERIC_TYPE_REGEX = T.let(/(#{SIMPLE_TYPE_REGEX})\s*[<{]\s*(.*)\s*[>}]/, T.untyped)
    DUCK_TYPE_REGEX = T.let(/^\#[a-zA-Z_][\w]*(?:[a-zA-Z_][\w=]*)*(?:( ?\& ?\#)*[a-zA-Z_][\w=]*)*$/, T.untyped)
    ORDERED_LIST_REGEX = T.let(/^(?:Array|)\((.*)\s*\)$/, T.untyped)
    SHORTHAND_HASH_SYNTAX = T.let(/^{\s*(.*)\s*}$/, T.untyped)
    SHORTHAND_ARRAY_SYNTAX = T.let(/^<\s*(.*)\s*>$/, T.untyped)
    SINGLE_ARG_GENERIC_TYPES = T.let(%w{Array Set Enumerable Enumerator Range}, T.untyped)

    # Given a string of YARD type parameters (without angle brackets), splits
    # the string into an array of each type parameter.
    # 
    # _@param_ `params` — The type parameters.
    # 
    # _@return_ — The split type parameters.
    sig { params(params: String).returns(T::Array[String]) }
    def self.split_type_parameters(params); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # sord warn - Parlour::Types::Type wasn't able to be resolved to a constant in this project
    # Converts a YARD type into a Parlour type.
    # 
    # _@param_ `yard` — The YARD type.
    # 
    # _@param_ `item` — The CodeObject which the YARD type is associated with. This is used for logging and can be nil, but this will lead to less informative log messages.
    # 
    # _@param_ `replace_errors_with_untyped` — If true, T.untyped is used instead of SORD_ERROR_ constants for unknown types.
    # 
    # _@param_ `replace_unresolved_with_untyped` — If true, T.untyped is used when Sord is unable to resolve a constant.
    sig do
      params(
        yard: T.any(T::Boolean, T::Array[T.untyped], String),
        item: T.nilable(YARD::CodeObjects::Base),
        replace_errors_with_untyped: T::Boolean,
        replace_unresolved_with_untyped: T::Boolean
      ).returns(Parlour::Types::Type)
    end
    def self.yard_to_parlour(yard, item = nil, replace_errors_with_untyped = false, replace_unresolved_with_untyped = false); end

    # sord warn - Parlour::Types::Type wasn't able to be resolved to a constant in this project
    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    # sord warn - Parlour::Types::Type wasn't able to be resolved to a constant in this project
    # Handles SORD_ERRORs.
    # 
    # _@param_ `name`
    # 
    # _@param_ `log_warning`
    # 
    # _@param_ `item`
    # 
    # _@param_ `replace_errors_with_untyped`
    sig do
      params(
        name: T.any(String, Parlour::Types::Type),
        log_warning: String,
        item: YARD::CodeObjects::Base,
        replace_errors_with_untyped: T::Boolean
      ).returns(Parlour::Types::Type)
    end
    def self.handle_sord_error(name, log_warning, item, replace_errors_with_untyped); end
  end
end
