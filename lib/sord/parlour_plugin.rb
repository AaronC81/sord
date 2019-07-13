require 'parlour'

module Sord
  class ParlourPlugin < Parlour::Plugin
    attr_reader :options
    attr_accessor :parlour

    def initialize(options)
      @parlour = nil
      @options = options

      options[:comments] = true if options[:comments].nil?
      options[:regenerate] = true if options[:regenerate].nil?
      options[:replace_errors_with_untyped] ||= false
      options[:replace_unresolved_with_untyped] ||= false
    end

    def generate(root)
      if options[:include_messages] && options[:exclude_messages]
        Sord::Logging.error('Please specify only one of --include-messages and --exclude-messages.')
        return false
      elsif options[:include_messages]
        whitelist = options[:include_messages].map { |x| x.downcase.to_sym }
        unless Sord::Logging.valid_types?(whitelist)
          Sord::Logging.error('Not all types on your --include-messages list are valid.')
          Sord::Logging.error("Valid options are: #{Sord::Logging::AVAILABLE_TYPES.map(&:to_s).join(', ')}")
          return false
        end
        Sord::Logging.enabled_types = whitelist | [:done]
      elsif options[:exclude_messages]
        blacklist = options[:exclude_messages].map { |x| x.downcase.to_sym }
        unless Sord::Logging.valid_types?(blacklist)
          Sord::Logging.error('Not all types on your --include-messages list are valid.')
          Sord::Logging.error("Valid options are: #{Sord::Logging::AVAILABLE_TYPES.map(&:to_s).join(', ')}")
          return false
        end
        Sord::Logging.enabled_types = Sord::Logging::AVAILABLE_TYPES - blacklist
      end
  
      if options[:regenerate]
        begin
          Sord::Logging.info('Running YARD...')
          Bundler.with_clean_env do
            system('bundle exec yard')
          end
        rescue Errno::ENOENT
          Sord::Logging.error('The YARD tool could not be found on your PATH.')
          Sord::Logging.error('You may need to run \'gem install yard\'.')
          Sord::Logging.error('If documentation has already been generated, pass --no-regenerate to Sord.')
          return false
        end
      end

      options[:parlour] = @parlour
      options[:root] = root

      Sord::RbiGenerator.new(options).run

      true
    end
  end
end