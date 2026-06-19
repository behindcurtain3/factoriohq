require "test_helper"

class FactorioServerTest < ActiveSupport::TestCase
  setup { @server = factorio_servers(:one) }

  test "fixture is valid" do
    assert @server.valid?
  end

  test "requires a name" do
    server = build_server(name: nil)
    assert_not server.valid?
    assert server.errors[:name].present?
  end

  test "name must be unique" do
    server = build_server(name: @server.name)
    assert_not server.valid?
    assert server.errors[:name].present?
  end

  test "port must be within the valid range" do
    assert_not build_server(port: 80).valid?,    "port below 1024 should be invalid"
    assert_not build_server(port: 70_000).valid?, "port above 65535 should be invalid"
    assert build_server(port: 35_000).valid?
  end

  test "port and rcon_port must be unique" do
    assert_not build_server(port: @server.port).valid?
    assert_not build_server(rcon_port: @server.rcon_port).valid?
  end

  test "generates passwords for a new server during validation" do
    server = build_server(rcon_password: nil, admin_password: nil)
    server.valid?
    assert server.rcon_password.present?
    assert server.admin_password.present?
  end

  test "status helpers reflect the status column" do
    assert factorio_servers(:one).stopped?
    assert_not factorio_servers(:one).running?
    assert factorio_servers(:two).running?
  end

  test "the local host is always ready with no status message" do
    assert @server.host_ready?
    assert_nil @server.host_status_message
  end

  test "start is refused when the host is not ready" do
    stub_method(@server, :host_ready?, false) do
      assert_not @server.start
    end

    assert @server.reload.stopped?
  end

  # --- Docker namespacing (production stays legacy; other envs are prefixed) ---

  test "container name is unprefixed in production" do
    with_rails_env("production") do
      assert_nil FactorioServer.namespace
      assert_equal "factorio-server-#{@server.id}", @server.container_name
    end
  end

  test "container name is namespaced outside production" do
    with_rails_env("development") do
      assert_equal "development", FactorioServer.namespace
      assert_equal "factorio-development-server-#{@server.id}", @server.container_name
    end
  end

  # --- Configurable Docker image repository ---

  test "image_repository defaults to factoriotools" do
    assert_equal "factoriotools/factorio", FactorioServer.image_repository
  end

  test "image_repository reflects the site setting" do
    SiteSetting.set("factorio_image_repository", "ghcr.io/owner/factorio")
    assert_equal "ghcr.io/owner/factorio", FactorioServer.image_repository
  end

  test "image_reference combines repository and tag" do
    assert_equal "factoriotools/factorio:latest", @server.image_reference("latest")
    @server.version = "2.0.55"
    assert_equal "factoriotools/factorio:2.0.55", @server.image_reference
  end

  test "normalize_image_repository cleans input" do
    assert_equal "factoriotools/factorio", FactorioServer.normalize_image_repository("  ")
    assert_equal "factoriotools/factorio", FactorioServer.normalize_image_repository("factoriotools/factorio:latest")
    assert_equal "registry.example.com:5000/owner/factorio",
                 FactorioServer.normalize_image_repository("registry.example.com:5000/owner/factorio:1.2.3")
  end

  test "docker_hub_repository is nil for custom registries" do
    assert_equal "factoriotools/factorio", FactorioServer.docker_hub_repository
    SiteSetting.set("factorio_image_repository", "ghcr.io/owner/factorio")
    assert_nil FactorioServer.docker_hub_repository
  end

  test "available_versions reads a configured versions.json for a custom registry" do
    Rails.cache.clear
    SiteSetting.set("factorio_image_repository", "ghcr.io/owner/factorio")
    SiteSetting.set("factorio_versions_url", "https://example.com/versions.json")
    json = { latest: "2.0.77", stable: "2.0.76", versions: [ "2.0.77", "2.0.76" ] }.to_json

    stub_method(Net::HTTP, :get, ->(*) { json }) do
      assert_equal [ "latest", "stable", "2.0.77", "2.0.76" ], FactorioServer.available_versions
    end
  end

  test "available_versions omits stable and falls back when the versions url is absent or broken" do
    Rails.cache.clear
    SiteSetting.set("factorio_image_repository", "ghcr.io/owner/factorio")
    assert_equal [ "latest" ], FactorioServer.available_versions

    Rails.cache.clear
    SiteSetting.set("factorio_versions_url", "https://example.com/versions.json")
    stub_method(Net::HTTP, :get, ->(*) { raise "boom" }) do
      assert_equal [ "latest" ], FactorioServer.available_versions
    end
  end

  # --- Server admins ---

  test "admin_list parses usernames separated by commas, spaces, or newlines" do
    server = build_server(admin_usernames: "Alice, bob\n charlie\tAlice")
    assert_equal %w[Alice bob charlie], server.admin_list
  end

  test "admin_list is empty when unset" do
    assert_equal [], build_server(admin_usernames: nil).admin_list
    assert_equal [], build_server(admin_usernames: "   ").admin_list
  end

  private

  def build_server(**attrs)
    FactorioServer.new({
      user: users(:one),
      name: "Brand New Server",
      port: 40_000,
      rcon_port: 41_000
    }.merge(attrs))
  end
end
