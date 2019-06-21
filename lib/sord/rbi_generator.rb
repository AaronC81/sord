# typed: true
require 'yard'
require 'sord/type_converter'
require 'colorize'

module Sord
  class RbiGenerator
    attr_reader :rbi_contents, :object_count

    def initialize
      @rbi_contents = []
      @object_count = 0
    end

    def count_object
      @object_count += 1
    end

    def add_mixins(item)
      extends = item.instance_mixins
      includes = item.class_mixins

      extends.each do |this_extend|
        rbi_contents << "  extend #{this_extend.path}"
      end
      includes.each do |this_include|
        rbi_contents << "  include #{this_include.path}"
      end
    end

    def warn(msg, item)
      puts "#{'[WARN]'.yellow} #{msg}"
      puts "         In #{item.path}".light_white
      rbi_contents << "\# sord warning: #{msg}"
    end

    def add_methods(item)
      item.meths.each do |meth|
        count_object

        parameter_list = meth.parameters.map do |name, default|
          # TODO: is it possible to differentiate between no default, and the 
          # default being nil?
          "#{name} = #{default.nil? ? 'nil' : default}"
        end.join(", ")

        params_list = meth.tags('param').map do |param|
          "#{param.name}: #{TypeConverter.yard_to_sorbet(param.types) { |x|
            warn(x, meth)
          }}"
        end.join(", ")

        returns = meth.tags('return').length == 0 \
          ? "void"
          : "returns(#{
            TypeConverter.yard_to_sorbet(meth.tag('return').types) { |x|
              warn(x, meth)
            }})"

        prefix = meth.scope == :class ? 'self.' : ''

        rbi_contents << "  sig { params(#{params_list}).#{returns} }"

        rbi_contents << "  def #{prefix}#{meth.name}(#{parameter_list}) end"
      end
    end

    def run(filename)
      # Get YARD ready
      YARD::Registry.load!

      # TODO: constants?

      # Populate the RBI with modules first
      YARD::Registry.all(:module).each do |item|
        count_object
        
        rbi_contents << "module #{item.path}"
        add_mixins(item)
        add_methods(item)
        rbi_contents << "end"
      end

      # Now populate with classes
      YARD::Registry.all(:class).each do |item|
        count_object

        superclass = (item.superclass if item.superclass.to_s != "Object")
        rbi_contents << "class #{item.path} #{"< #{superclass}" if superclass}" 
        add_mixins(item)
        add_methods(item)        
        rbi_contents << "end"
      end

      # Write the file
      raise "no filename specified" unless filename
      File.write(filename, rbi_contents.join(?\n))

      puts "#{'[DONE]'.green} Processed #{object_count} objects"
    rescue
      puts "#{'[ERR ]'.red} #{$!}"
      $@.each do |line|
        puts "         #{line}".light_white
      end
    end
  end
end