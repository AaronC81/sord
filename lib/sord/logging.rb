# typed: true
require 'rainbow'

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

    # An array of all available logging types.
    AVAILABLE_TYPES = [:warn, :info, :duck, :error, :infer, :omit, :done].freeze

    @@enabled_types = AVAILABLE_TYPES

    # Sets the array of log messages types which should be processed. Any not on
    # this list will be discarded. This should be a subset of AVAILABLE_TYPES.
    # @param [Array<Symbol>] value
    # @return [void]
    def self.enabled_types=(value)
      raise 'invalid types' unless valid_types?(value)
      @@enabled_types = value
    end

    # Gets the array of log messages types which should be processed. Any not on
    # this list will be discarded.
    # @return [Array<Symbol>]
    # @return [void]
    def self.enabled_types
      @@enabled_types
    end

    # Returns a boolean indicating whether a given array is a valid value for 
    # #enabled_types.
    # @param [Array<Symbol>] value
    # @return [void]
    def self.valid_types?(value)
      (value - AVAILABLE_TYPES).empty?
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
    # @return [void]
    def self.generic(kind, header, msg, item, **opts)
      return unless enabled_types.include?(kind)

      message = if item
        (filename, line), = item.files
        "#{header} #{Rainbow("(#{item.path}) #{filename}:#{line}:").bold} #{msg}"
      else
        "#{header} #{msg}"
      end
      puts message unless silent?

      invoke_hooks(kind, msg, item, **opts)
    end

    # Print a warning message. This should be used for things which require the
    # user's attention but do not prevent the process from stopping.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @return [void]
    def self.warn(msg, item = nil, **opts)
      generic(:warn, Rainbow('[WARN ]').yellow, msg, item, **opts)
    end

    # Print an info message. This should be used for generic informational
    # messages which the user doesn't need to act on.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @return [void]
    def self.info(msg, item = nil, **opts)
      generic(:info, '[INFO ]', msg, item, **opts)
    end

    # Print a duck-typing message. This should be used when the YARD 
    # documentation contains duck typing, which isn't supported by Sorbet, so
    # it is substituted for something different.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @return [void]
    def self.duck(msg, item = nil, **opts)
      generic(:duck, Rainbow('[DUCK ]').cyan, msg, item, **opts)
    end

    # Print an error message. This should be used for things which require the
    # current process to stop.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @return [void]
    def self.error(msg, item = nil, **opts)
      generic(:error, Rainbow('[ERROR]').red, msg, item, **opts)
    end

    # Print an infer message. This should be used when the user should be told
    # that some information has been filled in or guessed for them, and that 
    # information is likely correct.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @return [void]
    def self.infer(msg, item = nil, **opts)
      generic(:infer, Rainbow('[INFER]').blue, msg, item, **opts)
    end

    # Print an omit message. This should be used as a special type of warning
    # to alert the user that there is some information missing, but this
    # information is not critical to the completion of the process.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @return [void]
    def self.omit(msg, item = nil, **opts)
      generic(:omit, Rainbow('[OMIT ]').magenta, msg, item, **opts)
    end

    # Print a done message. This should be used when a process completes
    # successfully.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @return [void]
    def self.done(msg, item = nil, **opts)
      generic(:done, Rainbow('[DONE ]').green, msg, item, **opts)
    end

    # Invokes all registered hooks on the logger.
    # @param [Symbol] kind The kind of log message this is.
    # @param [String] msg The log message to write.
    # @param [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @return [void]
    def self.invoke_hooks(kind, msg, item, **opts)
      @@hooks.each do |hook|
        hook.(kind, msg, item, **opts)
      end
    end

    # Adds a hook to the logger.
    # @yieldparam [Symbol] kind The kind of log message this is.
    # @yieldparam [String] msg The log message to write.
    # @yieldparam [YARD::CodeObjects::Base] item The CodeObject which this log 
    #  is associated with, if any. This is shown before the log message if it is
    #  specified.
    # @yieldreturn [void]
    # @return [void]
    def self.add_hook(&blk)
      @@hooks << blk
    end
  end
end
