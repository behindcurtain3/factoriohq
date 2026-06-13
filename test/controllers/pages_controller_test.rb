require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "shows the landing page to logged-out visitors" do
    get root_path

    assert_response :success
    assert_match "FactorioHQ", @response.body
    assert_select "a[href=?]", new_user_registration_path
    assert_select "a[href=?]", new_user_session_path
  end

  test "hides registration links when registrations are disabled" do
    SiteSetting.set("registrations_enabled", "false")
    get root_path

    assert_response :success
    assert_select "a[href=?]", new_user_registration_path, count: 0
    assert_select "a[href=?]", new_user_session_path
  end

  test "sends signed-in users to their servers" do
    sign_in users(:one)
    get root_path

    assert_redirected_to factorio_servers_path
  end
end
