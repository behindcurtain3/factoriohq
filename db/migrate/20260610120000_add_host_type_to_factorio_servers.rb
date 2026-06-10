class AddHostTypeToFactorioServers < ActiveRecord::Migration[8.1]
  def change
    add_column :factorio_servers, :host_type, :string, null: false, default: "local"
  end
end
