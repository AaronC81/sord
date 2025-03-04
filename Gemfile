source "https://rubygems.org"

# Specify your gem's dependencies in sord.gemspec
gemspec

# Not in gemspec so it doesn't get distributed or depended on by the built gem.
# Used by resolver tests, to ensure Sord can import bundled RBIs from gems.
gem 'resolver-test', path: 'spec/resolver-test-gem'
