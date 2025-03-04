require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

REPOS = {
  addressable: 'https://github.com/sporkmonger/addressable',
  bundler: 'https://github.com/bundler/bundler',
  discordrb: 'https://github.com/meew0/discordrb',
  gitlab: 'https://github.com/NARKOZ/gitlab',
  'graphql-ruby': 'https://github.com/rmosolgo/graphql-ruby',
  haml: 'https://github.com/haml/haml',
  oga: 'https://gitlab.com/yorickpeterse/oga',
  rouge: 'https://github.com/rouge-ruby/rouge',
  'rspec-core': 'https://github.com/rspec/rspec-core',
  yard: 'https://github.com/lsegal/yard',
  zeitwerk: 'https://github.com/fxn/zeitwerk'
}

# Thrown by tasks when some of the input arguments or state is invalid.
class ValidationError < StandardError
end

# Handles Sord examples, including checkout and running Sord to generate types.
class ExampleRunner
  attr_reader :mode, :mode_arg, :clean
  alias clean? clean

  # @param [String] mode "rbi" or "rbs".
  # @param [Boolean] clean Run Sord with additional options to generate minimal type output.
  def initialize(mode:, clean: false)
    @mode = mode
    @clean = clean

    if mode == 'rbi'
      @mode_arg = '--rbi'
    elsif mode == 'rbs'
      @mode_arg = '--rbs'
    else
      raise ValidationError, 'please specify \'rbi\' or \'rbs\'!'
    end
  end

  # Create the `sord_examples` directory, ready for checkouts.
  # @raise [ValidationError] If it already exists.
  def create_examples_dir
    if File.directory?(File.join(__dir__, 'sord_examples'))
      raise ValidationError, 'sord_examples directory already exists, please delete the directory or run a reseed!'
    end

    FileUtils.mkdir 'sord_examples'
  end

  # Check that the `sord_examples` directory exists.
  # @raise [ValidationError] If it doesn't.
  def validate_examples_dir
    unless File.directory?(File.join(__dir__, 'sord_examples'))
      raise ValidationError, 'The sord_examples directory does not exist. Have you run the seed task?'
    end
  end

  # Check out a repository, add Sord to its Gemfile, and install its dependencies.
  # @param [Symbol] name Name of the checkout.
  # @param [String] url Git URL.
  def prepare_checkout(name, url)
    Dir.chdir(File.join(__dir__, 'sord_examples')) do
      puts "Cloning #{name}..."
      system("git clone #{url} --depth=1")

      Dir.chdir(name.to_s) do
        # Add sord to gemfile.
        `echo "gem 'sord', path: '../../'" >> Gemfile`

        # Run bundle install.
        system('bundle install')
      end
    end
  end

  # Run Sord on a checked-out repository.
  # @param [Symbol] name Name of the checkout.
  def generate_types(name)
    puts "Generating rbi for #{name}..."

    Dir.chdir(File.join(__dir__, 'sord_examples', name.to_s)) do
      if clean?
        system("bundle exec sord ../#{name}.#{mode} #{mode_arg} --no-sord-comments --replace-errors-with-untyped --replace-unresolved-with-untyped")
      else
        system("bundle exec sord ../#{name}.#{mode} #{mode_arg}")
      end

      puts "#{name}.#{mode} generated!"
    end
  end
end

namespace :examples do
  require 'fileutils'
  require 'rainbow'

  desc "Clone git repositories and run Sord on them as examples"
  task :seed, [:mode, :clean] do |t, args|
    examples = ExampleRunner.new(**args)
    examples.create_examples_dir

    Bundler.with_clean_env do
      REPOS.each do |name, url|
        examples.prepare_checkout(name, url)
        examples.generate_types(name)
      end
    end

    puts Rainbow("Seeding complete!").green

  rescue ValidationError => e
    abort Rainbow(e.to_s).red
  end

  desc 'Regenerate the rbi files in sord_examples.'
  task :reseed, [:mode, :clean] do |t, args|
    examples = ExampleRunner.new(**args)
    examples.validate_examples_dir

    REPOS.keys.each do |name|
      examples.generate_types(name)
    end

    puts Rainbow("Re-seeding complete!").green

  rescue ValidationError => e
    abort Rainbow(e.to_s).red
  end
  
  desc 'Delete the sord_examples directory to allow the seeder to run again.'
  task :reset do
    FileUtils.rm_rf 'sord_examples' if File.directory?('sord_examples')
    puts Rainbow('Reset complete.').green
  end

  desc 'Typecheck each of the sord_examples rbi files.'
  task :typecheck, [:verbose] do |t, args|
    results_hash = {}
    REPOS.each do |name, url|
      Bundler.with_clean_env do
        puts "srb tc sord_examples/#{name}.rbi --ignore sord.rbi 2>&1"
        if args[:verbose]
          output = system("srb tc sord_examples/#{name}.rbi --ignore sord.rbi 2>&1")
        else
          output = `srb tc sord_examples/#{name}.rbi --ignore sord.rbi 2>&1`.split("\n").last
          results_hash[:"#{name}"] = output
        end
      end
    end
    
    unless args[:verbose]
      puts Rainbow("Errors").bold
      longest_name = results_hash.keys.map { |name| name.length }.max

      # Replace all values in results_hash with integer by parsing it.
      results_hash.each do |name, result|
        result.scan(/Errors\: (\d+)/) { |match| result = match.first.to_i }
        results_hash[name] = (result == "No errors! Great job.") ? 0 : result
      end

      # Print the right-aligned name and the number of errors, with different colors depending on the number of errors. 
      results_hash.each do |name, result|
        spaces_needed = longest_name - name.length
        output = "#{' ' * spaces_needed}#{name}: #{result}"
        case result
        when 0..5
          puts Rainbow(output).green.bright
        when 6..25
          puts Rainbow(output).green
        when 26..50
          puts Rainbow(output).red
        else
          puts Rainbow(output).red.bright
        end
      end
      # Report the Total.
      puts Rainbow("#{' ' * (longest_name - 'Total'.length)}Total: #{results_hash.values.inject(0, :+)}").bold
    end
  end
end
