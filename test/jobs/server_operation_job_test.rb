require "test_helper"

class ServerOperationJobTest < ActiveJob::TestCase
  test "an unknown operation marks the server errored and logs it" do
    server = factorio_servers(:one)

    assert_difference -> { server.server_logs.count }, 1 do
      ServerOperationJob.perform_now(server, "frobnicate")
    end

    assert_equal "error", server.reload.status
    last_log = server.server_logs.order(:created_at).last
    assert_equal "error", last_log.level
    assert_match "frobnicate", last_log.message
  end
end
