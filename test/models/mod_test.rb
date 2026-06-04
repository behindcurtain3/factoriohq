require "test_helper"

class ModTest < ActiveSupport::TestCase
  test "filename combines name and version" do
    mod = Mod.new(name: "space-exploration", version: "0.6.123")
    assert_equal "space-exploration_0.6.123.zip", mod.filename
  end

  test "requires name, version, and a server" do
    mod = Mod.new
    assert_not mod.valid?
    assert mod.errors[:name].present?
    assert mod.errors[:version].present?
    assert mod.errors[:factorio_server_id].present?
  end

  test "is valid when attached to a server" do
    mod = Mod.new(name: "krastorio2", version: "1.3.23", factorio_server: factorio_servers(:one))
    assert mod.valid?
  end
end
