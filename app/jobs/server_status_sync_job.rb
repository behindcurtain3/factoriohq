class ServerStatusSyncJob < ApplicationJob
  queue_as :default

  def perform
    puts "Synchronizing Factorio server statuses..."
    FactorioServer.find_each do |server|
      # Check if container exists and is running
      begin
        container = Docker::Container.get(server.container_name)
        container_info = container.info

        # Update status based on actual container state
        if container_info["State"]["Status"] == "running"
          server.update(status: "running", docker_container_id: container.id)
        else
          server.update(status: "stopped", docker_container_id: nil)
        end
      rescue Docker::Error::NotFoundError
        return unless server.running?
        # Container doesn't exist anymore
        server.update(status: "stopped", docker_container_id: nil)
        server.server_logs.create(
          level: "warn",
          message: "Container not found during server startup sync, marked as stopped",
          timestamp: Time.current
        )
      rescue => e
        server.update(status: "error")
        server.server_logs.create(
          level: "error",
          message: "Error checking container status during startup: #{e.message}",
          timestamp: Time.current
        )
      end
    end
  end
end
