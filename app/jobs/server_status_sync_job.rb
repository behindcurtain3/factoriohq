class ServerStatusSyncJob < ApplicationJob
  queue_as :default

  def perform
    puts "Synchronizing Factorio server statuses..."
    FactorioServer.find_each do |server|
      sync_server(server)
    end
  end

  private

  def sync_server(server)
    state = server.host_driver.container_state(server)

    case state.status
    when :running
      server.update(status: "running", docker_container_id: state.container_id)
    when :stopped
      server.update(status: "stopped", docker_container_id: nil)
    when :missing
      return unless server.running?

      server.update(status: "stopped", docker_container_id: nil)
      server.server_logs.create(
        level: "warn",
        message: "Container not found during server startup sync, marked as stopped",
        timestamp: Time.current
      )
    end
  rescue => e
    server.update(status: "error")
    server.server_logs.create(
      level: "error",
      message: "Error checking container status during startup: #{e.message}",
      timestamp: Time.current
    )
  end
end
