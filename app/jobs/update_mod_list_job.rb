class UpdateModListJob < ApplicationJob
  queue_as :default

  def perform(server)
    File.write(server.mod_list_path, server.get_mod_list.to_json)
  end
end
