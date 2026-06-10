# Host drivers encapsulate where and how game servers actually run. A driver
# is looked up by a server's host_type; this app ships the "local" driver
# (containers on this machine's Docker daemon). Other drivers can be added at
# boot via Hosting.register.
module Hosting
  class Error < StandardError; end

  # Raised by a driver when the game-server image cannot be pulled.
  class ImagePullError < Error; end

  # Raised by a driver when a server's container no longer exists.
  class ContainerMissingError < Error; end

  # Observed state of a server's container: status is :running, :stopped or
  # :missing; container_id is nil when missing.
  ContainerState = Struct.new(:status, :container_id)

  # Class names rather than classes so code reloading can't strand stale
  # constants in the registry.
  @registry = { "local" => "Hosting::LocalDockerHost" }

  class << self
    def register(host_type, driver_class_name)
      @registry[host_type.to_s] = driver_class_name.to_s
    end

    def driver_for(server)
      class_name = @registry[server.host_type]
      raise Error, "No host driver registered for host_type #{server.host_type.inspect}" unless class_name

      class_name.constantize.new
    end

    def registered?(host_type)
      @registry.key?(host_type.to_s)
    end
  end
end
