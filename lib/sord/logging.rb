module Sord
  module Logging
    @@hooks = []

    def self.warn(msg, item=nil)
      if item
        puts "#{'[WARN]'.yellow} (#{item.path.light_white}) #{msg}"
      else
        puts "#{'[WARN]'.yellow} #{msg}"
      end

      invoke_hooks(:warn, msg, item)
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