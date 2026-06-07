class DeleteModJob < ApplicationJob
  queue_as :default

  def perform(server, filename)
    path = File.join(server.mods_directory, filename)

    File.delete(path) if File.exist?(path)

    Rails.logger.info("Deleted mod file: #{filename}")
  end
end
