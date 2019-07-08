# typed: strong
module Sord
  module Logging
    sig { returns(T::Array[Proc]) }
    def self.hooks(); end

    sig { returns(T::Boolean) }
    def self.silent?(); end

    sig { params(value: T::Boolean).void }
    def self.silent=(value); end

    sig { params(value: T::Array[Symbol]).void }
    def self.enabled_types=(value); end

    sig { returns(T::Array[Symbol]) }
    def self.enabled_types(); end

    sig { params(value: T::Array[Symbol]).void }
    def self.valid_types?(value); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig do
      params(
        kind: Symbol,
        header: String,
        msg: String,
        item: YARD::CodeObjects::Base,
        indent_level: Integer
      ).void
    end
    def self.generic(kind, header, msg, item, indent_level = 0); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: YARD::CodeObjects::Base, indent_level: Integer).void }
    def self.warn(msg, item = nil, indent_level = 0); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: YARD::CodeObjects::Base, indent_level: Integer).void }
    def self.info(msg, item = nil, indent_level = 0); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: YARD::CodeObjects::Base, indent_level: Integer).void }
    def self.duck(msg, item = nil, indent_level = 0); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: YARD::CodeObjects::Base, indent_level: Integer).void }
    def self.error(msg, item = nil, indent_level = 0); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: YARD::CodeObjects::Base, indent_level: Integer).void }
    def self.infer(msg, item = nil, indent_level = 0); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: YARD::CodeObjects::Base, indent_level: Integer).void }
    def self.omit(msg, item = nil, indent_level = 0); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(msg: String, item: YARD::CodeObjects::Base, indent_level: Integer).void }
    def self.done(msg, item = nil, indent_level = 0); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig do
      params(
        kind: Symbol,
        msg: String,
        item: YARD::CodeObjects::Base,
        indent_level: Integer
      ).void
    end
    def self.invoke_hooks(kind, msg, item, indent_level = 0); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(blk: T.proc.params(kind: Symbol, msg: String, item: YARD::CodeObjects::Base, indent_level: Integer).void).void }
    def self.add_hook(&blk); end
  end

  module Resolver
    sig { void }
    def self.prepare(); end

    sig { void }
    def self.clear(); end

    sig { params(name: String).returns(T::Array[String]) }
    def self.paths_for(name); end

    sig { params(name: String).returns(T.nilable(String)) }
    def self.path_for(name); end

    sig { returns(T::Array[String]) }
    def self.builtin_classes(); end

    sig { params(name: String, item: Object).returns(T::Boolean) }
    def self.resolvable?(name, item); end
  end

  class RbiGenerator
    sig { returns(Integer) }
    def object_count(); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { returns(T::Array[[String, YARD::CodeObjects::Base, Integer]]) }
    def warnings(); end

    sig { params(options: Hash).void }
    def initialize(options); end

    sig { void }
    def count_namespace(); end

    sig { void }
    def count_method(); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
    sig { params(item: YARD::CodeObjects::Base).returns(Integer) }
    def add_mixins(item); end

    # sord warn - YARD::CodeObjects::NamespaceObject wasn't able to be resolved to a constant in this project
    sig { params(item: YARD::CodeObjects::NamespaceObject).void }
    def add_methods(item); end

    # sord warn - YARD::CodeObjects::NamespaceObject wasn't able to be resolved to a constant in this project
    sig { params(item: YARD::CodeObjects::NamespaceObject).void }
    def add_namespace(item); end

    sig { returns(String) }
    def generate(); end

    sig { params(filename: T.nilable(String)).void }
    def run(filename); end
  end

  module TypeConverter
    sig { params(params: String).returns(T::Array[String]) }
    def self.split_type_parameters(params); end

    # sord warn - YARD::CodeObjects::Base wasn't able to be resolved to a constant in this project
<<<<<<< HEAD
    sig { params(yard: T.any(T::Boolean, Array, String), item: YARD::CodeObjects::Base, replace_errors_with_untyped: T::Boolean).returns(String) }
    def self.yard_to_sorbet(yard, item = nil, replace_errors_with_untyped = false); end
=======
    sig do
      params(
        yard: T.any(T::Boolean, Array, String),
        item: YARD::CodeObjects::Base,
        indent_level: Integer,
        replace_errors_with_untyped: T::Boolean,
        replace_unresolved_with_untyped: T::Boolean
      ).returns(String)
    end
    def self.yard_to_sorbet(yard, item = nil, indent_level = 0, replace_errors_with_untyped = false, replace_unresolved_with_untyped = false); end
>>>>>>> master
  end
end