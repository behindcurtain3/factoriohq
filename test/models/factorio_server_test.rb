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

  # --- Docker namespacing (production stays legacy; other envs are prefixed) ---

  test "container name and data dir are unprefixed in production" do
    with_rails_env("production") do
      assert_nil FactorioServer.namespace
      assert_equal "factorio-server-#{@server.id}", @server.container_name
      assert @server.server_directory.end_with?("/servers/#{@server.id}")
      assert_not_includes @server.server_directory, "/production/"
    end
  end

  test "container name and data dir are namespaced outside production" do
    with_rails_env("development") do
      assert_equal "development", FactorioServer.namespace
      assert_equal "factorio-development-server-#{@server.id}", @server.container_name
      assert_includes @server.server_directory, "/development/servers/#{@server.id}"
    end
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

  def with_rails_env(name)
    original = Rails.env
    Rails.env = name
    yield
  ensure
    Rails.env = original
  end
end
