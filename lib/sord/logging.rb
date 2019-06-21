require 'colorize'

module Sord
  module Logging
    @@hooks = []

    def self.generic(kind, header, msg, item)
      if item
        puts "#{header} (#{item.path.light_white}) #{msg}"
      else
        puts "#{header} #{msg}"
      end

      invoke_hooks(kind, msg, item)
    end

    def self.warn(msg, item=nil)
      generic(:warn, '[WARN ]'.yellow, msg, item)
    end

    def self.error(msg, item=nil)
      generic(:error, '[ERROR]'.red, msg, item)
    end

    def self.infer(msg, item=nil)
      generic(:error, '[INFER]'.light_blue, msg, item)
    end

    def self.omit(msg, item=nil)
      generic(:omit, '[OMIT ]'.magenta, msg, item)
    end

    def self.done(msg, item=nil)
      generic(:done, '[DONE ]'.green, msg, item)
    end

    def self.invoke_hooks(type, msg, item)
      @@hooks.each do |hook|
        hook.(type, msg, item) rescue nil
      end
    end

    def self.add_hook(&blk)
      @@hooks << blk
    end
  end
end