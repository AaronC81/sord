# typed: true
require 'parlour'

module Sord
  class ParlourPlugin < Parlour::Plugin
    attr_reader :options
    attr_accessor :parlour

    def initialize(options)
      @parlour = nil
      @options = options

      options[:sord_comments] = true if options[:sord_comments].nil?
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

      if !(options[:rbi] || options[:rbs])
        Sord::Logging.error('No output format given; please specify --rbi or --rbs')
        exit 1
      end

      if (options[:rbi] && options[:rbs])
        Sord::Logging.error('You cannot specify both --rbi and --rbs; please use only one')
        exit 1
      end

      if options[:regenerate]
        begin
          Sord::Logging.info('Running YARD...')
          Sord::ParlourPlugin.with_clean_env do
            system('bundle exec yard --no-output')
          end
        rescue Errno::ENOENT
          Sord::Logging.error('The YARD tool could not be found on your PATH.')
          Sord::Logging.error('You may need to run \'gem install yard\'.')
          Sord::Logging.error('If documentation has already been generated, pass --no-regenerate to Sord.')
          return false
        end
      end

      options[:mode] = \
        if options[:rbi] then :rbi elsif options[:rbs] then :rbs end
      options[:parlour] = @parlour
      options[:root] = root

      Sord::Generator.new(options).run

      true
    end

    def self.with_clean_env &block
      meth = if Bundler.respond_to?(:with_unbundled_env)
               :with_unbundled_env
             else
               :with_clean_env
            end
      Bundler.send meth, &block
    end
  end
end
