require 'colorize'

module Sord
  # Handles writing logs to stdout and any other classes which request them.
  module Logging
    # This is an Array of callables which are all executed upon a log message.
    # The callables should take three parameters: (kind, msg, item).
    @@hooks = []

    # @return [Array<Proc>] The hooks registered on the logger.
    def self.hooks
      @@hooks
    end

    # Whether log messages should be printed or not.
    @@silent = false
    
    # @return [Boolean] Whether log messages should be printed or not. This is
    #   used for testing.
    def self.silent?
      @@silent
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
    # @param [Integer] indent_level The level at which to indent the code.
    def self.generic(kind, header, msg, item, indent_level = 0)
      if item
        puts "#{header} (#{item.path.bold}) #{msg}" unless silent?
      else
        puts "#{header} #{msg}" unless silent?
      end

      invoke_hooks(kind, msg, item, indent_level)
    end

    # Print a warning message. This should be used for things which require the
    # user's attention but do not prevent the process from stopping.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @param [Integer] indent_level The level at which to indent the code.
    def self.warn(msg, item = nil, indent_level = 0)
      generic(:warn, '[WARN ]'.yellow, msg, item, indent_level)
    end

    # Print a duck-typing message. This should be used when the YARD 
    # documentation contains duck typing, which isn't supported by Sorbet, so
    # it is substituted for something different.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @param [Integer] indent_level The level at which to indent the code.
    def self.duck(msg, item = nil, indent_level = 0)
      generic(:duck, '[DUCK ]'.cyan, msg, item, indent_level)
    end

    # Print an error message. This should be used for things which require the
    # current process to stop.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @param [Integer] indent_level The level at which to indent the code.
    def self.error(msg, item = nil, indent_level = 0)
      generic(:error, '[ERROR]'.red, msg, item, indent_level)
    end

    # Print an infer message. This should be used when the user should be told
    # that some information has been filled in or guessed for them, and that 
    # information is likely correct.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @param [Integer] indent_level The level at which to indent the code.
    def self.infer(msg, item = nil, indent_level = 0)
      generic(:infer, '[INFER]'.light_blue, msg, item, indent_level)
    end

    # Print an omit message. This should be used as a special type of warning
    # to alert the user that there is some information missing, but this
    # information is not critical to the completion of the process.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @param [Integer] indent_level The level at which to indent the code.
    def self.omit(msg, item = nil, indent_level = 0)
      generic(:omit, '[OMIT ]'.magenta, msg, item, indent_level)
    end

    # Print a done message. This should be used when a process completes
    # successfully.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @param [Integer] indent_level The level at which to indent the code.
    def self.done(msg, item = nil, indent_level = 0)
      generic(:done, '[DONE ]'.green, msg, item)
    end

    # Invokes all registered hooks on the logger.
    # @param [Symbol] kind The kind of log message this is.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @param [Integer] indent_level The level at which to indent the code.
    def self.invoke_hooks(kind, msg, item, indent_level = 0)
      @@hooks.each do |hook|
        hook.(kind, msg, item, indent_level) rescue nil
      end
    end

    # Adds a hook to the logger.
    # @yieldparam [Symbol] kind The kind of log message this is.
    # @yieldparam [String] msg The log message to write.
    # @yieldparam [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @yieldparam [Integer] indent_level The level at which to indent the code.
    # @yieldreturn [void]
    def self.add_hook(&blk)
      @@hooks << blk
    end
  end
end
