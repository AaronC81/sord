require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

REPOS = {
  addressable: 'https://github.com/sporkmonger/addressable',
  bundler: 'https://github.com/bundler/bundler',
  discordrb: 'https://github.com/meew0/discordrb',
  gitlab: 'https://github.com/NARKOZ/gitlab',
  haml: 'https://github.com/haml/haml',
  oga: 'https://gitlab.com/yorickpeterse/oga',
  rouge: 'https://github.com/rouge-ruby/rouge',
  'rspec-core': 'https://github.com/rspec/rspec-core',
  yard: 'https://github.com/lsegal/yard',
  zeitwerk: 'https://github.com/fxn/zeitwerk'
}

namespace :examples do
  require 'fileutils'
  require 'rainbow'

  desc "Clone git repositories and run Sord on them as examples"
  task :seed, [:clean] do |t, args|
    if File.directory?('sord_examples')
      puts Rainbow('sord_examples directory already exists, please delete the directory or run a reseed!').red
      exit
    end

    FileUtils.mkdir 'sord_examples'
    FileUtils.cd 'sord_examples'
    
    Bundler.with_clean_env do
      # Shallow clone each of the repositories, then bundle install and run sord.
      REPOS.each do |name, url|
        puts "Cloning #{name}..."
        system("git clone #{url} --depth=1")
        FileUtils.cd name.to_s
        # Add sord to gemfile.
        `echo "gem 'sord', path: '../../'" >> Gemfile`
        # Run bundle install.
        system('bundle install')
        # Generate sri
        puts "Generating rbi for #{name}..."
        if args[:clean]
          system("bundle exec sord ../#{name}.rbi --no-sord-comments --replace-errors-with-untyped --replace-unresolved-with-untyped")
        else
          system("bundle exec sord ../#{name}.rbi")
        end
        puts "#{name}.rbi generated!"
        FileUtils.cd '..'
      end
    end

    puts Rainbow("Seeding complete!").green
  end

  desc 'Regenerate the rbi files in sord_examples.'
  task :reseed, [:clean] do |t, args|
    if Dir.exist?('sord_examples')
      FileUtils.cd 'sord_examples'
    else
      raise Rainbow("The sord_examples directory does not exist. Have you run the seed task?").red.bold
    end

    REPOS.keys.each do |name|
      FileUtils.cd name.to_s
      puts "Regenerating rbi file for #{name}..."
      Bundler.with_clean_env do
        if args[:clean]
          system("bundle exec sord ../#{name}.rbi --no-regenerate --no-sord-comments --replace-errors-with-untyped --replace-unresolved-with-untyped")
        else
          system("bundle exec sord ../#{name}.rbi --no-regenerate")
        end
      end
      FileUtils.cd '..'
    end

    puts Rainbow("Re-seeding complete!").green
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
