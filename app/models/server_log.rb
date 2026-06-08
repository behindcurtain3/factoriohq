class ServerLog < ApplicationRecord
  belongs_to :factorio_server

  after_create_commit do
    broadcast_prepend_to factorio_server,
                         target: "server-logs",
                         partial: "server_logs/log_entry",
                         locals: { log: self }
  end
end
