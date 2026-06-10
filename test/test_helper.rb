ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Minimal replacement for minitest/mock's `stub` (no longer bundled as of
    # Minitest 6): temporarily replaces a method on the receiver for the
    # duration of the block, then restores the original.
    def stub_method(receiver, name, impl)
      metaclass = receiver.singleton_class
      saved = :"__stubbed_#{name}"
      metaclass.alias_method(saved, name)
      metaclass.define_method(name) do |*args, **kwargs, &block|
        impl.respond_to?(:call) ? impl.call(*args, **kwargs, &block) : impl
      end
      yield
    ensure
      metaclass.alias_method(name, saved)
      metaclass.remove_method(saved)
    end
  end
end
