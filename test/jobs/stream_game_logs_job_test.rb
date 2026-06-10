require "test_helper"

class StreamGameLogsJobTest < ActiveJob::TestCase
  # Stands in for Docker::Container, replaying canned log chunks.
  class FakeContainer
    def initialize(chunks)
      @chunks = chunks
    end

    def streaming_logs(stdout:, stderr:, follow:, since:, &block)
      @chunks.each { |chunk| block.call(:stdout, chunk) }
    end
  end

  test "persists deduplicated log lines from the container stream" do
    server = factorio_servers(:two)
    server.update!(docker_container_id: "deadbeef")

    # One line per chunk, as Docker delivers them. (Control characters --
    # including newlines -- are stripped before splitting, so a multi-line
    # chunk would be glued into a single message.)
    fake = FakeContainer.new([ "line one\n", "line two\n", "line two\n" ])
    stub_method(Docker::Container, :get, ->(_id) { fake }) do
      StreamGameLogsJob.perform_now(server.id)
    end

    assert_equal [ "line one", "line two" ], server.game_logs.pluck(:message).sort
  end

  test "does nothing for a server that is not running" do
    server = factorio_servers(:one)

    StreamGameLogsJob.perform_now(server.id)

    # No Docker stub in place: reaching the daemon would have raised.
    assert_equal "stopped", server.reload.status
  end

  test "reschedules itself when streaming fails while the server is running" do
    server = factorio_servers(:two)
    server.update!(docker_container_id: "deadbeef")

    stub_method(Docker::Container, :get, ->(_id) { raise "connection reset" }) do
      StreamGameLogsJob.perform_now(server.id)
    end

    assert_enqueued_with(job: StreamGameLogsJob, args: [ server.id ])
  end
end
