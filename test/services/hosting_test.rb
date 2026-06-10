require "test_helper"

class HostingTest < ActiveSupport::TestCase
  test "servers default to the local docker driver" do
    server = factorio_servers(:one)

    assert_equal "local", server.host_type
    assert_instance_of Hosting::LocalDockerHost, server.host_driver
  end

  test "raises for an unregistered host_type" do
    server = factorio_servers(:one)
    server.host_type = "droplet"

    error = assert_raises(Hosting::Error) { Hosting.driver_for(server) }
    assert_match "droplet", error.message
  end

  test "drivers can be registered by class name" do
    Hosting.register("hosting-test-driver", "Hosting::LocalDockerHost")

    server = factorio_servers(:one)
    server.host_type = "hosting-test-driver"

    assert_instance_of Hosting::LocalDockerHost, Hosting.driver_for(server)
  end
end
