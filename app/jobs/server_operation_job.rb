class ServerOperationJob < ApplicationJob
  queue_as :default

  def perform(server, operation)
    case operation
    when "start"
      start_server(server)
    when "stop"
      stop_server(server)
    else
      server.update(status: "error")
      server.server_logs.create(level: "error", message: "Unknown operation: #{operation}", timestamp: Time.current)
    end
  end

  private

  def start_server(server)
    spec = Hosting::ContainerSpec.for(server)

    # The selected save applies to this start only; clear it so the next
    # start loads the latest save again.
    server.update(save_file: nil) if server.save_file.present?

    container_id = server.host_driver.start_server(server, spec)

    server.update(docker_container_id: container_id, status: "running")
    server.server_logs.create(level: "info", message: "Server started with version #{spec.version}", timestamp: Time.current)

    # Clear existing game logs
    server.game_logs.delete_all

    # Start log synchronization
    StreamGameLogsJob.perform_later(server.id)

  rescue Hosting::ImagePullError => e
    server.update(status: "error")
    server.server_logs.create(level: "error", message: e.message, timestamp: Time.current)
  rescue => e
    server.update(status: "error")
    server.server_logs.create(level: "error", message: "Failed to start server: #{e.message}", timestamp: Time.current)
  end

  def stop_server(server)
    return unless server.docker_container_id.present?

    # Cancel game logs streaming
    StreamGameLogsJob.cancel_by(server_id: server.id) if defined?(StreamGameLogsJob.cancel_by)

    server.host_driver.stop_server(server)
    server.update(docker_container_id: nil, status: "stopped")
    server.server_logs.create(level: "info", message: "Server stopped", timestamp: Time.current)
  rescue Hosting::ContainerMissingError
    # Container already deleted, just update status
    server.update(docker_container_id: nil, status: "stopped")
    server.server_logs.create(level: "warn", message: "Container not found, marked as stopped", timestamp: Time.current)
  rescue => e
    server.update(status: "error")
    server.server_logs.create(level: "error", message: "Failed to stop server: #{e.message}", timestamp: Time.current)
  end
end
