require "test_helper"

class FactorioServersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "redirects guests to sign in" do
    get factorio_servers_path
    assert_redirected_to new_user_session_path
  end

  test "lists only the signed-in user's servers" do
    sign_in users(:one)
    get factorio_servers_path

    assert_response :success
    assert_match "Alpha Base", @response.body          # owned by user :one
    assert_no_match(/Beta Base/, @response.body)        # owned by user :two
  end

  test "cannot view another user's server" do
    sign_in users(:one)
    get factorio_server_path(factorio_servers(:two))
    assert_response :not_found
  end

  test "shows an owned server" do
    sign_in users(:one)
    get factorio_server_path(factorio_servers(:one))
    assert_response :success
    assert_match "Alpha Base", @response.body
  end
end
