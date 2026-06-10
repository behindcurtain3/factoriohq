class StreamGameLogsJob < ApplicationJob
  queue_as :logs

  def perform(server_id)
    server = FactorioServer.find_by(id: server_id)
    return unless server&.running? && server&.docker_container_id.present?

    begin
      # Get timestamp of last log to avoid duplication
      last_log_time = server.game_logs.maximum(:created_at) || Time.at(0)

      server.host_driver.stream_logs(server, since: last_log_time) do |chunk|
        process_log_chunk(server, chunk)
      end
    rescue => e
      Rails.logger.error "Log streaming error: #{e.message}"

      # If streaming fails, reschedule the job to try again
      if server.reload.running?
        StreamGameLogsJob.set(wait: 10.seconds).perform_later(server_id)
      end
    end
  end

  private

  def process_log_chunk(server, chunk)
    # Clean the chunk
    clean_chunk = chunk.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
                      .gsub(/[\x00-\x1F\x7F]/, "")

    # Process each line
    clean_chunk.split("\n").each do |line|
      next if line.blank?

      # Create a unique hash
      log_hash = Digest::MD5.hexdigest("#{line}")

      # Create log entry if it doesn't exist
      unless server.game_logs.exists?(log_hash: log_hash)
        server.game_logs.create(
          message: line,
          log_hash: log_hash
        )
      end
    end
  rescue => e
    Rails.logger.error "Error processing log chunk: #{e.message}"
  end
end
