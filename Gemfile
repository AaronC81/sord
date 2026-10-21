source "https://rubygems.org"

# Specify your gem's dependencies in sord.gemspec
gemspec

# TEMPORARY: Parlour::Types::Nil is unreleased; drop this pin and bump the
# gemspec's parlour requirement once a parlour release includes it.
gem 'parlour', git: 'https://github.com/apiology/parlour', branch: 'add-nil-type'

# Not in gemspec so it doesn't get distributed or depended on by the built gem.
# Used by resolver tests, to ensure Sord can import bundled RBIs from gems.
gem 'resolver-test', path: 'spec/resolver-test-gem'
