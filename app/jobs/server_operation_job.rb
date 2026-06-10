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
    # Ensure the server's data directories exist before writing config and
    # bind-mounting them, in case they have not been created yet.
    FileUtils.mkdir_p(File.dirname(server.config_file_path))
    FileUtils.mkdir_p(server.saves_directory)
    FileUtils.mkdir_p(server.mods_directory)

    # Server settings
    File.write(server.config_file_path, server.server_settings.to_json)

    # Admin list (Factorio reads config/server-adminlist.json). Always written
    # so removing an admin takes effect on the next start.
    File.write(server.admin_list_path, server.admin_list.to_json)

    # RCON password. The factoriotools image reads this from config/rconpw and
    # ignores any RCON_PASSWORD env var, so we must write the file ourselves for
    # the app to be able to authenticate. Always overwrite so it stays in sync.
    File.write(server.rconpw_path, server.rcon_password)

    spec = Hosting::ContainerSpec.for(server)

    # The selected save applies to this start only; clear it so the next
    # start loads the latest save again.
    server.update(save_file: nil) if server.save_file.present?

    # Pull the image first to ensure it exists
    begin
      Docker::Image.create("fromImage" => spec.image)
    rescue => e
      server.update(status: "error")
      server.server_logs.create(
        level: "error",
        message: "Failed to pull Docker image #{spec.image}: #{e.message}. Make sure this tag exists in the configured image repository.",
        timestamp: Time.current
      )
      return
    end

    container = Docker::Container.create(spec.to_docker_config(server.server_directory))

    # Start the container
    container.start

    server.update(docker_container_id: container.id, status: "running")
    server.server_logs.create(level: "info", message: "Server started with version #{spec.version}", timestamp: Time.current)

    # Clear existing game logs
    server.game_logs.delete_all

    # Start log synchronization
    StreamGameLogsJob.perform_later(server.id)

  rescue => e
    server.update(status: "error")
    server.server_logs.create(level: "error", message: "Failed to start server: #{e.message}", timestamp: Time.current)
  end

  def stop_server(server)
    return unless server.docker_container_id.present?

    begin
      # Cancel game logs streaming
      StreamGameLogsJob.cancel_by(server_id: server.id) if defined?(StreamGameLogsJob.cancel_by)

      container = Docker::Container.get(server.docker_container_id)
      container.stop
      container.delete(force: true)
      server.update(docker_container_id: nil, status: "stopped")
      server.server_logs.create(level: "info", message: "Server stopped", timestamp: Time.current)
    rescue Docker::Error::NotFoundError
      # Container already deleted, just update status
      server.update(docker_container_id: nil, status: "stopped")
      server.server_logs.create(level: "warn", message: "Container not found, marked as stopped", timestamp: Time.current)
    rescue => e
      server.update(status: "error")
      server.server_logs.create(level: "error", message: "Failed to stop server: #{e.message}", timestamp: Time.current)
    end
  end
end
