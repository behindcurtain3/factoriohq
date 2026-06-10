require "test_helper"

module Hosting
  class LocalDockerHostTest < ActiveSupport::TestCase
    setup do
      @driver = LocalDockerHost.new
      @server = factorio_servers(:one)
    end

    test "data dir is unprefixed in production" do
      with_rails_env("production") do
        assert @driver.server_directory(@server).end_with?("/servers/#{@server.id}")
        assert_not_includes @driver.server_directory(@server), "/production/"
      end
    end

    test "data dir is namespaced by environment outside production" do
      with_rails_env("development") do
        assert_includes @driver.server_directory(@server), "/development/servers/#{@server.id}"
      end
    end

    test "config and mod files live under the server directory" do
      assert @driver.config_file_path(@server).end_with?("/config/server-settings.json")
      assert @driver.admin_list_path(@server).end_with?("/config/server-adminlist.json")
      assert @driver.rconpw_path(@server).end_with?("/config/rconpw")
      assert @driver.mod_list_path(@server).end_with?("/mods/mod-list.json")
      assert @driver.saves_directory(@server).end_with?("/saves")
    end

    test "rcon is reached on the loopback interface" do
      assert_equal "127.0.0.1", @driver.rcon_host(@server)
    end

    test "game host is nil because the app host serves the game" do
      assert_nil @driver.game_host(@server)
    end
  end
end
