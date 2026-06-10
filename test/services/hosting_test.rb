require "test_helper"

class HostingTest < ActiveSupport::TestCase
  test "servers default to the local docker driver" do
    server = factorio_servers(:one)

    assert_equal "local", server.host_type
    assert_instance_of Hosting::LocalDockerHost, server.host_driver
  end

  test "raises for an unregistered host_type" do
    server = factorio_servers(:one)
    server.host_type = "never-registered"

    error = assert_raises(Hosting::Error) { Hosting.driver_for(server) }
    assert_match "never-registered", error.message
  end

  test "a server with an unregistered host_type is invalid" do
    server = factorio_servers(:one)
    server.host_type = "never-registered"

    assert_not server.valid?
    assert server.errors[:host_type].present?
  end

  test "drivers can be registered by class name" do
    Hosting.register("hosting-test-driver", "Hosting::LocalDockerHost")

    server = factorio_servers(:one)
    server.host_type = "hosting-test-driver"

    assert_instance_of Hosting::LocalDockerHost, Hosting.driver_for(server)
  end
end
