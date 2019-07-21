# typed: strong
module Sord
  VERSION = T.let('0.8.0', T.untyped)

  module Logging
    AVAILABLE_TYPES = T.let([:warn, :info, :duck, :error, :infer, :omit, :done].freeze, T.untyped)

    sig { returns(T::Array[Proc]) }
    def self.hooks; end

    sig { returns(T::Boolean) }
    def self.silent?; end

    sig { params(value: T::Boolean).void }
    def self.silent=(value); end

    sig { params(value: T::Array[Symbol]).void }
    def self.enabled_types=(value); end

    sig { returns(T::Array[Symbol]) }
    def self.enabled_types; end

    sig { params(value: T::Array[Symbol]).void }
    def self.valid_types?(value); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
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
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.warn(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.info(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.duck(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.error(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.infer(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.omit(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: T.nilable(YARD::CodeObjects::Base)).void }
    def self.done(msg, item = nil); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(kind: Symbol, msg: String, item: YARD::CodeObjects::Base).void }
    def self.invoke_hooks(kind, msg, item); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(blk: T.proc.params(kind: Symbol, msg: String, item: YARD::CodeObjects::Base).void).void }
    def self.add_hook(&blk); end
  end

  module Resolver
    sig { void }
    def self.prepare; end

    sig { void }
    def self.clear; end

    sig { params(name: String).returns(T::Array[String]) }
    def self.paths_for(name); end

    sig { params(name: String).returns(T.nilable(String)) }
    def self.path_for(name); end

    sig { returns(T::Array[String]) }
    def self.builtin_classes; end

    sig { params(name: String, item: Object).returns(T::Boolean) }
    def self.resolvable?(name, item); end
  end

  class RbiGenerator
    sig { returns(Integer) }
    def object_count; end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { returns(T::Array[[String, YARD::CodeObjects::Base, Integer]]) }
    def warnings; end

    sig { params(options: T::Hash[T.untyped, T.untyped]).void }
    def initialize(options); end

    sig { void }
    def count_namespace; end

    sig { void }
    def count_method; end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(item: YARD::CodeObjects::Base).returns(Integer) }
    def add_mixins(item); end

    # sord warn - YARD::CodeObjects::NamespaceObject wasn't able to be resolved to a constant in this project
    sig { params(item: YARD::CodeObjects::NamespaceObject).void }
    def add_constants(item); end

    # sord warn - YARD::CodeObjects::NamespaceObject wasn't able to be resolved to a constant in this project
    sig { params(item: YARD::CodeObjects::NamespaceObject).void }
    def add_methods(item); end

    # sord warn - YARD::CodeObjects::NamespaceObject wasn't able to be resolved to a constant in this project
    sig { params(item: YARD::CodeObjects::NamespaceObject).void }
    def add_namespace(item); end

    sig { void }
    def populate; end

    sig { void }
    def generate; end

    sig { void }
    def run; end
  end

  class ParlourPlugin < Parlour::Plugin
    # sord omit - no YARD return type given, using T.untyped
    sig { returns(T.untyped) }
    def options; end

    # sord omit - no YARD return type given, using T.untyped
    sig { returns(T.untyped) }
    def parlour; end

    # sord omit - no YARD return type given, using T.untyped
    sig { params(value: T.untyped).returns(T.untyped) }
    def parlour=(value); end

    # sord omit - no YARD type given for "options", using T.untyped
    sig { params(options: T.untyped).returns(ParlourPlugin) }
    def initialize(options); end

    # sord omit - no YARD type given for "root", using T.untyped
    # sord omit - no YARD return type given, using T.untyped
    sig { params(root: T.untyped).returns(T.untyped) }
    def generate(root); end
  end

  module TypeConverter
    SIMPLE_TYPE_REGEX = T.let(/(?:\:\:)?[a-zA-Z_][\w]*(?:\:\:[a-zA-Z_][\w]*)*/, T.untyped)
    GENERIC_TYPE_REGEX = T.let(/(#{SIMPLE_TYPE_REGEX})\s*[<{]\s*(.*)\s*[>}]/, T.untyped)
    DUCK_TYPE_REGEX = T.let(/^\#[a-zA-Z_][\w]*(?:[a-zA-Z_][\w=]*)*(?:( ?\& ?\#)*[a-zA-Z_][\w=]*)*$/, T.untyped)
    ORDERED_LIST_REGEX = T.let(/^(?:Array|)\((.*)\s*\)$/, T.untyped)
    SHORTHAND_HASH_SYNTAX = T.let(/^{\s*(.*)\s*}$/, T.untyped)
    SHORTHAND_ARRAY_SYNTAX = T.let(/^<\s*(.*)\s*>$/, T.untyped)
    SORBET_SUPPORTED_GENERIC_TYPES = T.let(%w{Array Set Enumerable Enumerator Range Hash Class}, T.untyped)
    SORBET_SINGLE_ARG_GENERIC_TYPES = T.let(%w{Array Set Enumerable Enumerator Range}, T.untyped)

    sig { params(params: String).returns(T::Array[String]) }
    def self.split_type_parameters(params); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig do
      params(
        yard: T.any(T::Boolean, T::Array[T.untyped], String),
        item: T.nilable(YARD::CodeObjects::Base),
        replace_errors_with_untyped: T::Boolean,
        replace_unresolved_with_untyped: T::Boolean
      ).returns(String)
    end
    def self.yard_to_sorbet(yard, item = nil, replace_errors_with_untyped = false, replace_unresolved_with_untyped = false); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig do
      params(
        name: String,
        log_warning: String,
        item: YARD::CodeObjects::Base,
        replace_errors_with_untyped: T::Boolean
      ).returns(String)
    end
    def self.handle_sord_error(name, log_warning, item, replace_errors_with_untyped); end
  end
end