require "test_helper"

class ServerStatusSyncJobTest < ActiveJob::TestCase
  # Stands in for Docker::Container in state lookups.
  class FakeContainer
    attr_reader :id

    def initialize(id, status)
      @id = id
      @status = status
    end

    def info
      { "State" => { "Status" => @status } }
    end
  end

  test "syncs every server to its actual container state" do
    stopped_in_db = factorio_servers(:one)   # actually running
    running_in_db = factorio_servers(:two)   # actually exited

    containers = {
      stopped_in_db.container_name => FakeContainer.new("c-one", "running"),
      running_in_db.container_name => FakeContainer.new("c-two", "exited")
    }

    stub_method(Docker::Container, :get, ->(name) { containers.fetch(name) }) do
      ServerStatusSyncJob.perform_now
    end

    stopped_in_db.reload
    assert_equal "running", stopped_in_db.status
    assert_equal "c-one", stopped_in_db.docker_container_id

    running_in_db.reload
    assert_equal "stopped", running_in_db.status
    assert_nil running_in_db.docker_container_id
  end

  test "a running server whose container vanished is marked stopped with a warning" do
    server = factorio_servers(:two)

    stub_method(Docker::Container, :get, ->(_name) { raise Docker::Error::NotFoundError }) do
      ServerStatusSyncJob.perform_now
    end

    server.reload
    assert_equal "stopped", server.status
    assert_nil server.docker_container_id
    assert_equal "warn", server.server_logs.order(:created_at).last.level
  end

  test "a stopped server with no container is left alone" do
    server = factorio_servers(:one)

    assert_no_difference -> { server.server_logs.count } do
      stub_method(Docker::Container, :get, ->(_name) { raise Docker::Error::NotFoundError }) do
        ServerStatusSyncJob.perform_now
      end
    end

    assert_equal "stopped", server.reload.status
  end

  test "errors while checking are recorded per server and the sweep continues" do
    one = factorio_servers(:one)
    two = factorio_servers(:two)

    stub_method(Docker::Container, :get, ->(_name) { raise "daemon unreachable" }) do
      ServerStatusSyncJob.perform_now
    end

    [ one, two ].each do |server|
      assert_equal "error", server.reload.status
      assert_match "daemon unreachable", server.server_logs.order(:created_at).last.message
    end
  end
end
