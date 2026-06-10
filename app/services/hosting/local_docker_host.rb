module Hosting
  # Runs game servers on the same machine as the app: containers via the
  # local Docker daemon, data under FACTORIO_DATA_PATH on local disk.
  class LocalDockerHost
    # Returns the id of the started container.
    def start_server(server, spec)
      prepare(server)
      write_config_files(server)
      pull_image(spec.image)

      container = Docker::Container.create(spec.to_docker_config(server.server_directory))
      container.start
      container.id
    end

    def stop_server(server)
      container = Docker::Container.get(server.docker_container_id)
      container.stop
      container.delete(force: true)
    rescue Docker::Error::NotFoundError
      raise ContainerMissingError, "Container #{server.docker_container_id} not found"
    end

    def container_exists?(server)
      Docker::Container.get(server.docker_container_id)
      true
    rescue Docker::Error::NotFoundError
      false
    end

    def check_for_updates(server)
      return unless server.docker_container_id.present?

      begin
        latest_image = Docker::Image.create("fromImage" => server.image_reference("latest"))

        container = Docker::Container.get(server.docker_container_id)
        current_image_id = container.info["Image"]

        if latest_image.id != current_image_id && server.version == "latest"
          return {
            update_available: true,
            current_id: current_image_id,
            latest_id: latest_image.id
          }
        end
      rescue => e
        return { error: e.message }
      end

      { update_available: false }
    end

    def prepare(server)
      FileUtils.mkdir_p(server.server_directory)
      FileUtils.mkdir_p(server.saves_directory)
      FileUtils.mkdir_p(server.mods_directory)
      FileUtils.mkdir_p(File.dirname(server.config_file_path))
    end

    def write_config_files(server)
      File.write(server.config_file_path, server.server_settings.to_json)

      # Admin list (Factorio reads config/server-adminlist.json). Always written
      # so removing an admin takes effect on the next start.
      File.write(server.admin_list_path, server.admin_list.to_json)

      # RCON password. The factoriotools image reads this from config/rconpw and
      # ignores any RCON_PASSWORD env var, so we must write the file ourselves for
      # the app to be able to authenticate. Always overwrite so it stays in sync.
      File.write(server.rconpw_path, server.rcon_password)
    end

    def rcon_host(_server)
      "127.0.0.1"
    end

    private

    def pull_image(image)
      Docker::Image.create("fromImage" => image)
    rescue => e
      raise ImagePullError,
            "Failed to pull Docker image #{image}: #{e.message}. Make sure this tag exists in the configured image repository."
    end
  end
end
