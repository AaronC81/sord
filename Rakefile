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
  rouge: 'https://github.com/rouge-ruby/rouge',
  'rspec-core': 'https://github.com/rspec/rspec-core',
  yard: 'https://github.com/lsegal/yard',
  zeitwerk: 'https://github.com/fxn/zeitwerk'
}

namespace :examples do
  require 'fileutils'

  desc "Clone git repositories and run Sord on them as examples"
  task :seed do
    require 'colorize'

    if File.directory?('sord_examples')
      puts 'sord_examples directory already exists, please delete the directory before seeding, or run a reseed!'.red
      exit
    end

    FileUtils.mkdir 'sord_examples'
    FileUtils.cd 'sord_examples'

    # Shallow clone each of the repositories and then bundle install and run sord.
    REPOS.each do |name, url|
      puts "Cloning #{name}..."
      `git clone #{url} --depth=1`
      FileUtils.cd name.to_s
      # Add sord to gemfile.
      `echo "gem 'sord', path: '../../'" >> Gemfile`
      # Run bundle install.
      `bundle install`
      # Generate sri
      puts "Generating rbi for #{name}..."
      `bundle exec sord ../#{name}.rbi`
      puts "#{name}.rbi generated!"
      FileUtils.cd '..'
    end

    puts "Seeding complete!"
  end

  desc 'Regenerate the rbi files in sord_examples.'
  task :reseed do
    FileUtils.cd 'sord_examples'
    REPOS.keys.each do |name|
      FileUtils.cd name.to_s
      puts "Regenerating rbi file for #{name}..."
      system("bundle exec sord ../#{name}.rbi --no-regenerate")
      FileUtils.cd '..'
    end

    puts "Re-seeding complete!"
  end
  
  desc 'Delete the sord_examples directory to allow the seeder to run again.'
  task :reset do
    FileUtils.rm_rf 'sord_examples' if File.directory?('sord_examples')
    puts 'Reset complete.'
  end
end

