class Mod < ApplicationRecord
  belongs_to :factorio_server

  validates :name, presence: true
  validates :version, presence: true
  validates :factorio_server_id, presence: true

  after_create :update_mod_list
  after_destroy :update_mod_list
  after_destroy :delete_mod_files
  after_update :update_mod_list

  def filename
    name + "_" + version + ".zip"
  end

  def update_mod_list
    UpdateModListJob.perform_later(factorio_server)
  end

  def delete_mod_files
    DeleteModJob.perform_later(factorio_server, filename)
  end
end
