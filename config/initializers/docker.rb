require "docker"

# Configure Docker API
Docker.url = ENV["DOCKER_URL"] || "unix:///var/run/docker.sock"

# Test Docker connection on startup
begin
  Docker.version
  Rails.logger.info "Connected to Docker daemon: #{Docker.version['Version']}"
rescue => e
  Rails.logger.error "Failed to connect to Docker daemon: #{e.message}"
end
