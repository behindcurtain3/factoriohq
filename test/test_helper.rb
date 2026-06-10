ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Points FACTORIO_DATA_PATH at a throwaway directory for tests that touch
# server files on disk.
module TmpFactorioData
  extend ActiveSupport::Concern

  included do
    setup do
      @original_data_path = ENV["FACTORIO_DATA_PATH"]
      @factorio_data_dir = Dir.mktmpdir
      ENV["FACTORIO_DATA_PATH"] = @factorio_data_dir
    end

    teardown do
      ENV["FACTORIO_DATA_PATH"] = @original_data_path
      FileUtils.remove_entry(@factorio_data_dir) if File.directory?(@factorio_data_dir)
    end
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # The local driver, for asserting against on-disk storage paths.
    def local_host
      @local_host ||= Hosting::LocalDockerHost.new
    end

    def with_rails_env(name)
      original = Rails.env
      Rails.env = name
      yield
    ensure
      Rails.env = original
    end

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
