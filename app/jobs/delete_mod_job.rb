class DeleteModJob < ApplicationJob
  queue_as :default

  def perform(server, filename)
    server.host_driver.delete_mod(server, filename)

    Rails.logger.info("Deleted mod file: #{filename}")
  end
end
