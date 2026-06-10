module Hosting
  # Everything needed to run a Factorio game-server container, derived purely
  # from a FactorioServer's configuration. Values are captured at build time,
  # so later changes to the record (e.g. clearing save_file) don't alter an
  # already-built spec. Host drivers consume this so a container is configured
  # identically wherever it runs.
  class ContainerSpec
    attr_reader :image, :version, :container_name, :hostname,
                :game_port, :rcon_port, :env

    def self.for(server)
      new(server)
    end

    def initialize(server)
      @version = server.version.presence || "latest"
      @image = server.image_reference(@version)
      @container_name = server.container_name
      @hostname = "factorio-#{server.id}"
      @game_port = server.port
      @rcon_port = server.rcon_port
      @env = build_env(server)
    end

    # The Docker create payload. The data directory is the host path mounted
    # at /factorio; only the driver knows where that lives.
    def to_docker_config(data_dir)
      {
        "name" => container_name,
        "Image" => image,
        "Hostname" => hostname,
        "ExposedPorts" => {
          "#{game_port}/udp" => {},
          "#{rcon_port}/tcp" => {}
        },
        "HostConfig" => {
          "Binds" => [
            "#{data_dir}:/factorio"
          ],
          "PortBindings" => {
            "#{game_port}/udp" => [ { "HostPort" => game_port.to_s } ],
            "#{rcon_port}/tcp" => [ { "HostPort" => rcon_port.to_s } ]
          },
          "RestartPolicy" => {
            "Name" => "always"
          }
        },
        "Env" => env
      }
    end

    private

    def build_env(server)
      vars = []

      # SAVE_NAME applies to a single start; without it the image loads the
      # latest save.
      if server.save_file.present?
        vars << "SAVE_NAME=#{server.save_file}"
        vars << "LOAD_LATEST_SAVE=false"
      end

      dlc_flags = []
      dlc_flags << "space-age" if server.enable_space_age
      dlc_flags << "elevated-rails" if server.enable_elevated_rails
      dlc_flags << "quality" if server.enable_quality
      vars << if dlc_flags.empty?
        "DLC_SPACE_AGE=false"
      else
        "DLC_SPACE_AGE=#{dlc_flags.join(' ')}"
      end

      vars << "RCON_PORT=#{server.rcon_port}"
      vars << "PORT=#{server.port}"
      vars << "TOKEN=#{server.user.factorio_token}" if server.user.factorio_token.present?
      vars << "UPDATE_MODS_ON_START=true" if server.auto_update_mods
      vars
    end
  end
end
