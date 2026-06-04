require "test_helper"

class Admin::SiteSettingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "non-admins are denied" do
    sign_in users(:two) # admin: false
    get admin_site_settings_path
    assert_redirected_to root_path
  end

  test "admin sees the settings page" do
    sign_in users(:one) # admin: true
    get admin_site_settings_path
    assert_response :success
    assert_match "Factorio Docker Image", @response.body
  end

  test "admin can set the factorio image repository, stripping any tag" do
    sign_in users(:one)
    patch admin_site_settings_path, params: { factorio_image_repository: "ghcr.io/owner/factorio:latest" }
    assert_redirected_to admin_site_settings_path
    assert_equal "ghcr.io/owner/factorio", SiteSetting.get("factorio_image_repository")
  end

  test "blank repository falls back to the default" do
    sign_in users(:one)
    patch admin_site_settings_path, params: { factorio_image_repository: "   " }
    assert_equal FactorioServer::DEFAULT_IMAGE_REPOSITORY, SiteSetting.get("factorio_image_repository")
  end
end
