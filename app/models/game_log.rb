class GameLog < ApplicationRecord
  belongs_to :factorio_server

  default_scope { order(created_at: :desc) }

  after_create_commit do
    broadcast_prepend_to factorio_server,
                         target: "game-logs",
                         partial: "game_logs/log_entry",
                         locals: { log: self }
  end
end
