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

  # --- RCON console ---

  class FakeRcon
    def initialize(response: nil, error: nil)
      @response = response
      @error = error
    end

    def execute(_command)
      raise @error if @error
      @response
    end
  end

  test "console rejects commands while the server is stopped" do
    sign_in users(:one)

    post console_factorio_server_path(factorio_servers(:one)), params: { command: "/time" }

    assert_response :bad_request
    assert_equal false, response.parsed_body["success"]
  end

  test "console rejects blank commands" do
    sign_in users(:two)

    post console_factorio_server_path(factorio_servers(:two)), params: { command: "   " }

    assert_response :bad_request
  end

  test "console executes a command over RCON against the local host" do
    sign_in users(:two)
    server = factorio_servers(:two)
    rcon_args = nil

    stub_method(RconService, :new, ->(*args) { rcon_args = args; FakeRcon.new(response: "Time is 42") }) do
      post console_factorio_server_path(server), params: { command: "/time" }
    end

    assert_response :success
    assert_equal "Time is 42", response.parsed_body["response"]
    assert_equal [ "127.0.0.1", server.rcon_port, server.rcon_password ], rcon_args

    last_log = server.server_logs.order(:created_at).last
    assert_match "/time", last_log.message
  end

  test "console reports RCON failures" do
    sign_in users(:two)

    error = RconService::RconError.new("authentication failed")
    stub_method(RconService, :new, ->(*_args) { FakeRcon.new(error: error) }) do
      post console_factorio_server_path(factorio_servers(:two)), params: { command: "/time" }
    end

    assert_response :unprocessable_entity
    assert_match "authentication failed", response.parsed_body["error"]
  end
end
