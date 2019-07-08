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
  require 'colorize'

  desc "Clone git repositories and run Sord on them as examples"
  task :seed, [:clean] do |t, args|
    if File.directory?('sord_examples')
      puts 'sord_examples directory already exists, please delete the directory or run a reseed!'.red
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
          system("bundle exec sord ../#{name}.rbi --no-comments --replace-errors-with-untyped")
        else
          system("bundle exec sord ../#{name}.rbi")
        end
        puts "#{name}.rbi generated!"
        FileUtils.cd '..'
      end
    end

    puts "Seeding complete!".green
  end

  desc 'Regenerate the rbi files in sord_examples.'
  task :reseed, [:clean] do |t, args|
    FileUtils.cd 'sord_examples'

    REPOS.keys.each do |name|
      FileUtils.cd name.to_s
      puts "Regenerating rbi file for #{name}..."
      Bundler.with_clean_env do
        if args[:clean]
          system("bundle exec sord ../#{name}.rbi --no-regenerate --no-comments --replace-errors-with-untyped")
        else
          system("bundle exec sord ../#{name}.rbi --no-regenerate")
        end
      end
      FileUtils.cd '..'
    end

    puts "Re-seeding complete!".green
  end
  
  desc 'Delete the sord_examples directory to allow the seeder to run again.'
  task :reset do
    FileUtils.rm_rf 'sord_examples' if File.directory?('sord_examples')
    puts 'Reset complete.'.green
  end

  desc 'Typecheck each of the sord_examples rbi files.'
  task :typecheck do
    REPOS.each do |name, url|
      Bundler.with_clean_env do
        cmd = "srb tc sord_examples/#{name}.rbi --ignore sord.rbi"
        puts cmd
        system(cmd)
      end
    end
  end
end
