class AddServerSettingsToFactorioServers < ActiveRecord::Migration[8.0]
  def change
    add_column :factorio_servers, :visibility_public, :boolean, default: true
    add_column :factorio_servers, :visibility_lan, :boolean, default: true
    add_column :factorio_servers, :require_user_verification, :boolean, default: true
    add_column :factorio_servers, :max_upload_in_kilobytes_per_second, :integer, default: 0
    add_column :factorio_servers, :max_upload_slots, :integer, default: 5
    add_column :factorio_servers, :minimum_latency_in_ticks, :integer, default: 0
    add_column :factorio_servers, :ignore_player_limit_for_returning_players, :boolean, default: false
    add_column :factorio_servers, :allow_commands, :string, default: "admins-only"
    add_column :factorio_servers, :autosave_interval, :integer, default: 10
    add_column :factorio_servers, :autosave_slots, :integer, default: 5
    add_column :factorio_servers, :afk_autokick_interval, :integer, default: 0
    add_column :factorio_servers, :auto_pause, :boolean, default: true
    add_column :factorio_servers, :only_admins_can_pause_the_game, :boolean, default: true
    add_column :factorio_servers, :autosave_only_on_server, :boolean, default: true
    add_column :factorio_servers, :non_blocking_saving, :boolean, default: false
    add_column :factorio_servers, :minimum_segment_size, :integer, default: 25
    add_column :factorio_servers, :minimum_segment_size_peer_count, :integer, default: 20
    add_column :factorio_servers, :maximum_segment_size, :integer, default: 100
    add_column :factorio_servers, :maximum_segment_size_peer_count, :integer, default: 10
  end
end
