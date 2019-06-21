require 'simplecov'
SimpleCov.start

require_relative '../lib/sord'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end

RSpec::Matchers.define :log do |kind|
  match do |actual|
    call_parameters = []
    Sord::Logging.add_hook do |*a|
      call_parameters << a
    end
    
    actual.call

    call_parameters.length == 1 && (kind.nil? || call_parameters.first.first == kind)
  end

  supports_block_expectations
end
