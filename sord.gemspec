
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sord/version"

Gem::Specification.new do |spec|
  spec.name          = "sord"
  spec.version       = Sord::VERSION
  spec.authors       = ["Aaron Christiansen"]
  spec.email         = ["aaronc20000@gmail.com"]

  spec.summary       = "Generate Sorbet RBI files from YARD documentation"
  spec.homepage      = "https://github.com/AaronC81/sord"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|sorbet)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'yard'
  spec.add_dependency 'sorbet-runtime'
  spec.add_dependency 'commander', '~> 5.0'
  spec.add_dependency "parser"
  spec.add_dependency 'parlour', '~> 9.1'
  spec.add_dependency 'rbs', '>=3.0', '<5'

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency 'sorbet'
  spec.add_development_dependency 'simplecov'
end
