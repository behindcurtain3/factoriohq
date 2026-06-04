require "test_helper"

class SiteSettingTest < ActiveSupport::TestCase
  test "requires a key" do
    assert_not SiteSetting.new(value: "x").valid?
  end

  test "key must be unique" do
    duplicate = SiteSetting.new(key: site_settings(:registrations_enabled).key)
    assert_not duplicate.valid?
  end

  test "get returns the stored value or the default" do
    assert_equal "true", SiteSetting.get("registrations_enabled")
    assert_equal "fallback", SiteSetting.get("missing_key", "fallback")
    assert_nil SiteSetting.get("missing_key")
  end

  test "set creates then updates a setting" do
    SiteSetting.set("welcome_message", "hello")
    assert_equal "hello", SiteSetting.get("welcome_message")

    SiteSetting.set("welcome_message", "updated")
    assert_equal "updated", SiteSetting.get("welcome_message")
  end
end
