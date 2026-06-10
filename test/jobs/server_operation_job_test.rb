require "test_helper"

class ServerOperationJobTest < ActiveJob::TestCase
  # Stands in for Docker::Container so tests never need a Docker daemon.
  class FakeContainer
    attr_reader :id

    def initialize(id)
      @id = id
    end

    def start = @started = true
    def started? = !!@started
    def stop = @stopped = true
    def stopped? = !!@stopped
    def delete(force: false) = @deleted = true
    def deleted? = !!@deleted
  end

  include TmpFactorioData

  test "an unknown operation marks the server errored and logs it" do
    server = factorio_servers(:one)

    assert_difference -> { server.server_logs.count }, 1 do
      ServerOperationJob.perform_now(server, "frobnicate")
    end

    assert_equal "error", server.reload.status
    last_log = server.server_logs.order(:created_at).last
    assert_equal "error", last_log.level
    assert_match "frobnicate", last_log.message
  end

  # --- start ---

  test "start writes config files, creates and starts the container" do
    server = factorio_servers(:one)
    server.game_logs.create!(message: "stale line", log_hash: "stale")

    container = FakeContainer.new("abc123")
    created_config = nil

    stub_method(Docker::Image, :create, ->(_opts) { :pulled }) do
      stub_method(Docker::Container, :create, ->(config) { created_config = config; container }) do
        ServerOperationJob.perform_now(server, "start")
      end
    end

    server.reload
    assert_equal "running", server.status
    assert_equal "abc123", server.docker_container_id
    assert container.started?

    # Config files land in the server directory
    settings = JSON.parse(File.read("#{local_host.server_directory(server)}/config/server-settings.json"))
    assert_equal "Alpha Base", settings["name"]
    assert_equal "[]", File.read(local_host.admin_list_path(server))
    assert_equal "alpha-rcon", File.read(local_host.rconpw_path(server))

    # Container is wired to the right image, name, ports and bind mount
    assert_equal server.container_name, created_config["name"]
    assert_equal "factoriotools/factorio:latest", created_config["Image"]
    assert_includes created_config["HostConfig"]["Binds"], "#{local_host.server_directory(server)}:/factorio"
    assert_equal [ { "HostPort" => "34197" } ], created_config["HostConfig"]["PortBindings"]["34197/udp"]
    assert_equal [ { "HostPort" => "27015" } ], created_config["HostConfig"]["PortBindings"]["27015/tcp"]
    assert_includes created_config["Env"], "PORT=34197"
    assert_includes created_config["Env"], "RCON_PORT=27015"

    # Old game logs are cleared and streaming restarts
    assert_equal 0, server.game_logs.count
    assert_enqueued_with(job: StreamGameLogsJob, args: [ server.id ])

    last_log = server.server_logs.order(:created_at).last
    assert_equal "info", last_log.level
    assert_match "started", last_log.message
  end

  test "start passes the selected save file once and then clears it" do
    server = factorio_servers(:one)
    server.update!(save_file: "world.zip")

    created_config = nil
    stub_method(Docker::Image, :create, ->(_opts) { :pulled }) do
      stub_method(Docker::Container, :create, ->(config) { created_config = config; FakeContainer.new("abc123") }) do
        ServerOperationJob.perform_now(server, "start")
      end
    end

    assert_includes created_config["Env"], "SAVE_NAME=world.zip"
    assert_includes created_config["Env"], "LOAD_LATEST_SAVE=false"
    assert_nil server.reload.save_file
  end

  test "start disables DLC when all DLC toggles are off" do
    server = factorio_servers(:one)
    server.update!(enable_space_age: false, enable_elevated_rails: false, enable_quality: false)

    created_config = nil
    stub_method(Docker::Image, :create, ->(_opts) { :pulled }) do
      stub_method(Docker::Container, :create, ->(config) { created_config = config; FakeContainer.new("abc123") }) do
        ServerOperationJob.perform_now(server, "start")
      end
    end

    assert_includes created_config["Env"], "DLC_SPACE_AGE=false"
  end

  test "start marks the server errored when the image pull fails" do
    server = factorio_servers(:one)

    stub_method(Docker::Image, :create, ->(_opts) { raise "no such tag" }) do
      ServerOperationJob.perform_now(server, "start")
    end

    assert_equal "error", server.reload.status
    last_log = server.server_logs.order(:created_at).last
    assert_equal "error", last_log.level
    assert_match "factoriotools/factorio:latest", last_log.message
  end

  test "start marks the server errored when container creation fails" do
    server = factorio_servers(:one)

    stub_method(Docker::Image, :create, ->(_opts) { :pulled }) do
      stub_method(Docker::Container, :create, ->(_config) { raise "port already allocated" }) do
        ServerOperationJob.perform_now(server, "start")
      end
    end

    assert_equal "error", server.reload.status
    assert_match "port already allocated", server.server_logs.order(:created_at).last.message
  end

  # --- stop ---

  test "stop stops and deletes the container" do
    server = factorio_servers(:two)
    server.update!(docker_container_id: "deadbeef")

    container = FakeContainer.new("deadbeef")
    stub_method(Docker::Container, :get, ->(id) { assert_equal "deadbeef", id; container }) do
      ServerOperationJob.perform_now(server, "stop")
    end

    assert container.stopped?
    assert container.deleted?
    server.reload
    assert_equal "stopped", server.status
    assert_nil server.docker_container_id
    last_log = server.server_logs.order(:created_at).last
    assert_equal "info", last_log.level
    assert_match "stopped", last_log.message
  end

  test "stop marks the server stopped when the container is already gone" do
    server = factorio_servers(:two)
    server.update!(docker_container_id: "deadbeef")

    stub_method(Docker::Container, :get, ->(_id) { raise Docker::Error::NotFoundError }) do
      ServerOperationJob.perform_now(server, "stop")
    end

    server.reload
    assert_equal "stopped", server.status
    assert_nil server.docker_container_id
    assert_equal "warn", server.server_logs.order(:created_at).last.level
  end

  test "stop marks the server errored on unexpected failures" do
    server = factorio_servers(:two)
    server.update!(docker_container_id: "deadbeef")

    stub_method(Docker::Container, :get, ->(_id) { raise "daemon unreachable" }) do
      ServerOperationJob.perform_now(server, "stop")
    end

    assert_equal "error", server.reload.status
    assert_match "daemon unreachable", server.server_logs.order(:created_at).last.message
  end

  test "stop is a no-op when no container is recorded" do
    server = factorio_servers(:one)

    assert_no_difference -> { server.server_logs.count } do
      ServerOperationJob.perform_now(server, "stop")
    end

    assert_equal "stopped", server.reload.status
  end
end
