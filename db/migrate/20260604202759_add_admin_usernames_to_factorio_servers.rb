class AddAdminUsernamesToFactorioServers < ActiveRecord::Migration[8.0]
  def change
    add_column :factorio_servers, :admin_usernames, :text
  end
end
