require "test_helper"

module Hosting
  class ContainerSpecTest < ActiveSupport::TestCase
    setup { @server = factorio_servers(:one) }

    test "defaults to the latest image tag" do
      spec = ContainerSpec.for(@server)

      assert_equal "latest", spec.version
      assert_equal "factoriotools/factorio:latest", spec.image
    end

    test "uses the server's pinned version" do
      spec = ContainerSpec.for(factorio_servers(:two))

      assert_equal "2.0.55", spec.version
      assert_equal "factoriotools/factorio:2.0.55", spec.image
    end

    test "carries the container identity and ports" do
      spec = ContainerSpec.for(@server)

      assert_equal @server.container_name, spec.container_name
      assert_equal "factorio-#{@server.id}", spec.hostname
      assert_equal 34197, spec.game_port
      assert_equal 27015, spec.rcon_port
      assert_includes spec.env, "PORT=34197"
      assert_includes spec.env, "RCON_PORT=27015"
    end

    test "enables all owned DLC by default" do
      assert_includes ContainerSpec.for(@server).env,
                      "DLC_SPACE_AGE=space-age elevated-rails quality"
    end

    test "lists only the enabled DLC" do
      @server.update!(enable_space_age: false)

      assert_includes ContainerSpec.for(@server).env,
                      "DLC_SPACE_AGE=elevated-rails quality"
    end

    test "disables DLC when all toggles are off" do
      @server.update!(enable_space_age: false, enable_elevated_rails: false, enable_quality: false)

      assert_includes ContainerSpec.for(@server).env, "DLC_SPACE_AGE=false"
    end

    test "passes the selected save file" do
      @server.update!(save_file: "world.zip")
      spec = ContainerSpec.for(@server)

      assert_includes spec.env, "SAVE_NAME=world.zip"
      assert_includes spec.env, "LOAD_LATEST_SAVE=false"
    end

    test "omits save file variables when none is selected" do
      env = ContainerSpec.for(@server).env

      assert_not env.any? { |var| var.start_with?("SAVE_NAME=", "LOAD_LATEST_SAVE=") }
    end

    test "is a snapshot: clearing save_file afterwards does not change the env" do
      @server.update!(save_file: "world.zip")
      spec = ContainerSpec.for(@server)
      @server.update!(save_file: nil)

      assert_includes spec.env, "SAVE_NAME=world.zip"
    end

    test "includes the owner's factorio token when present" do
      assert_includes ContainerSpec.for(@server).env, "TOKEN=secret-token"

      tokenless = ContainerSpec.for(factorio_servers(:two))
      assert_not tokenless.env.any? { |var| var.start_with?("TOKEN=") }
    end

    test "enables mod updates on start when configured" do
      assert_not_includes ContainerSpec.for(@server).env, "UPDATE_MODS_ON_START=true"

      @server.update!(auto_update_mods: true)
      assert_includes ContainerSpec.for(@server).env, "UPDATE_MODS_ON_START=true"
    end

    test "to_docker_config mounts the given data directory and binds the ports" do
      config = ContainerSpec.for(@server).to_docker_config("/data/servers/1")

      assert_equal @server.container_name, config["name"]
      assert_equal "factoriotools/factorio:latest", config["Image"]
      assert_equal [ "/data/servers/1:/factorio" ], config["HostConfig"]["Binds"]
      assert_equal({ "34197/udp" => {}, "27015/tcp" => {} }, config["ExposedPorts"])
      assert_equal [ { "HostPort" => "34197" } ], config["HostConfig"]["PortBindings"]["34197/udp"]
      assert_equal [ { "HostPort" => "27015" } ], config["HostConfig"]["PortBindings"]["27015/tcp"]
      assert_equal "always", config["HostConfig"]["RestartPolicy"]["Name"]
    end
  end
end
