require 'colorize'

module Sord
  # Handles writing logs to stdout and any other classes which request them.
  module Logging
    # This is an Array of callables which are all executed upon a log message.
    # The callables should take three parameters: (kind, msg, item).
    @@hooks = []

    # @return [Boolean] Whether log messages should be printed or not. This is
    #   used for testing.
    def self.silent?
      @@silent || false
    end

    # Sets whether log messages should be printed or not.
    # @param [Boolean] value
    # @return [void]
    def self.silent=(value)
      @@silent = value
    end

    # A generic log message writer which is called by all other specific logging
    # methods. This shouldn't be called outside of the Logging class itself.
    # @param [Symbol] kind The kind of log message this is.
    # @param [String] header The prefix for this log message. For consistency,
    #   it should be up to five uppercase characters wrapped in square brackets,
    #   with some unique colour applied.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    def self.generic(kind, header, msg, item)
      if item
        puts "#{header} (#{item.path.light_white}) #{msg}" unless silent?
      else
        puts "#{header} #{msg}" unless silent?
      end

      invoke_hooks(kind, msg, item)
    end

    # Print a warning message. This should be used for things which require the
    # user's attention but do not prevent the process from stopping.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    def self.warn(msg, item=nil)
      generic(:warn, '[WARN ]'.yellow, msg, item)
    end

    # Print an error message. This should be used for things which require the
    # current process to stop.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    def self.error(msg, item=nil)
      generic(:error, '[ERROR]'.red, msg, item)
    end

    # Print an infer message. This should be used when the user should be told
    # that some information has been filled in or guessed for them, and that 
    # information is likely correct.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    def self.infer(msg, item=nil)
      generic(:infer, '[INFER]'.light_blue, msg, item)
    end

    # Print an omit message. This should be used as a special type of warning
    # to alert the user that there is some information missing, but this
    # information is not critical to the completion of the process.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    def self.omit(msg, item=nil)
      generic(:omit, '[OMIT ]'.magenta, msg, item)
    end

    # Print a done message. This should be used when a process completes
    # successfully.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    def self.done(msg, item=nil)
      generic(:done, '[DONE ]'.green, msg, item)
    end

    # Invokes all registered hooks on the logger.
    # @param [Symbol] kind The kind of log message this is.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    def self.invoke_hooks(kind, msg, item)
      @@hooks.each do |hook|
        hook.(kind, msg, item) rescue nil
      end
    end

    # Adds a hook to the logger.
    # @yieldparam [Symbol] kind The kind of log message this is.
    # @yieldparam [String] msg The log message to write.
    # @yieldparam [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @yieldreturn [void]
    def self.add_hook(&blk)
      @@hooks << blk
    end
  end
end