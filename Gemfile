source "https://rubygems.org"

# Specify your gem's dependencies in sord.gemspec
gemspec

# TEMPORARY: pending https://github.com/AaronC81/parlour/pull/152 (adds
# Parlour::Types::TypeVariable and generic class/module support) being merged
# and released. Revert to the gemspec's published version constraint once
# that ships.
gem 'parlour', git: 'https://github.com/apiology/parlour', branch: 'add_type_parameter_type'

# Not in gemspec so it doesn't get distributed or depended on by the built gem.
# Used by resolver tests, to ensure Sord can import bundled RBIs from gems.
gem 'resolver-test', path: 'spec/resolver-test-gem'
