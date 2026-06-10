module Hosting
  # Runs game servers on the same machine as the app: containers via the
  # local Docker daemon, data under FACTORIO_DATA_PATH on local disk.
  class LocalDockerHost
    # --- storage layout ---
    # Data dirs are namespaced by Rails environment for the same reason as
    # container names (see FactorioServer.namespace).

    def server_directory(server)
      root = ENV["FACTORIO_DATA_PATH"]
      namespace = FactorioServer.namespace
      root = "#{root}/#{namespace}" if namespace
      "#{root}/servers/#{server.id}"
    end

    def saves_directory(server)
      "#{server_directory(server)}/saves"
    end

    def mods_directory(server)
      "#{server_directory(server)}/mods"
    end

    def config_file_path(server)
      "#{server_directory(server)}/config/server-settings.json"
    end

    def mod_list_path(server)
      "#{mods_directory(server)}/mod-list.json"
    end

    def admin_list_path(server)
      "#{server_directory(server)}/config/server-adminlist.json"
    end

    # The factoriotools image reads the RCON password from this file (and would
    # otherwise generate a random one we don't know). Writing it lets us control
    # the password so the app can authenticate to RCON.
    def rconpw_path(server)
      "#{server_directory(server)}/config/rconpw"
    end

    # --- lifecycle ---

    # Returns the id of the started container.
    def start_server(server, spec)
      prepare(server)
      write_config_files(server)
      pull_image(spec.image)

      container = Docker::Container.create(spec.to_docker_config(server_directory(server)))
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

    # Looked up by name rather than recorded id so a lost docker_container_id
    # still resolves to the right container.
    def container_state(server)
      container = Docker::Container.get(server.container_name)

      if container.info["State"]["Status"] == "running"
        ContainerState.new(:running, container.id)
      else
        ContainerState.new(:stopped, container.id)
      end
    rescue Docker::Error::NotFoundError
      ContainerState.new(:missing, nil)
    end

    # Follows the container's output, yielding each chunk as it arrives.
    # Blocks until the container stops or the connection drops.
    def stream_logs(server, since:, &block)
      container = Docker::Container.get(server.docker_container_id)
      container.streaming_logs(stdout: true, stderr: true, follow: true, since: since.to_i) do |_stream, chunk|
        block.call(chunk)
      end
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
      FileUtils.mkdir_p(server_directory(server))
      FileUtils.mkdir_p(saves_directory(server))
      FileUtils.mkdir_p(mods_directory(server))
      FileUtils.mkdir_p(File.dirname(config_file_path(server)))
    end

    def write_config_files(server)
      File.write(config_file_path(server), server.server_settings.to_json)

      # Admin list (Factorio reads config/server-adminlist.json). Always written
      # so removing an admin takes effect on the next start.
      File.write(admin_list_path(server), server.admin_list.to_json)

      # RCON password (see rconpw_path). Always overwrite so it stays in sync.
      File.write(rconpw_path(server), server.rcon_password)
    end

    def list_saves(server)
      Dir.glob(File.join(saves_directory(server), "*.zip")).map do |file|
        {
          name: File.basename(file),
          size: File.size(file),
          modified: File.mtime(file)
        }
      end.sort_by { |file| file[:modified] }.reverse
    end

    # Local filesystem path for send_file, or nil when the save doesn't
    # exist. Remote drivers may expose a URL instead.
    def save_path_for_download(server, filename)
      path = File.join(saves_directory(server), filename)
      File.exist?(path) ? path : nil
    end

    def write_save(server, filename, io)
      FileUtils.mkdir_p(saves_directory(server))
      File.binwrite(File.join(saves_directory(server), filename), io.read)
    end

    # Returns false when the file was already gone.
    def delete_save(server, filename)
      path = File.join(saves_directory(server), filename)
      return false unless File.exist?(path)

      File.delete(path)
      true
    end

    def write_mod(server, filename, io)
      FileUtils.mkdir_p(mods_directory(server))
      File.binwrite(File.join(mods_directory(server), filename), io.read)
    end

    def write_mod_list(server)
      File.write(mod_list_path(server), server.get_mod_list.to_json)
    end

    def delete_mod(server, filename)
      path = File.join(mods_directory(server), filename)

      File.delete(path) if File.exist?(path)
    end

    def rcon_host(_server)
      "127.0.0.1"
    end

    # The host players connect to; nil means the game runs on the same host
    # that serves the app.
    def game_host(_server)
      nil
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
