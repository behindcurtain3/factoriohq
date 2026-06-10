class UpdateModListJob < ApplicationJob
  queue_as :default

  def perform(server)
    server.host_driver.write_mod_list(server)
  end
end
