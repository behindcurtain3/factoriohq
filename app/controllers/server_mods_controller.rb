class ServerModsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_mod, only: [ :destroy ]

  def index
    @server = current_user.factorio_servers.find(params[:factorio_server_id])
    @mods = @server.mods
  end

  def create
    @server = current_user.factorio_servers.find(params[:factorio_server_id])

    # Check if the server is running
    if @server.running?
      redirect_to factorio_server_server_mods_path(@server), alert: "Server is running. Please stop it before uploading mods."
      return
    end

    # Check if a file was uploaded
    if params[:mod_file].blank?
      redirect_to factorio_server_server_mods_path(@server), alert: "No file selected"
      return
    end

    uploaded_file = params[:mod_file]
    # Ensure file has .zip extension
    unless uploaded_file.original_filename.end_with?(".zip")
      redirect_to factorio_server_server_mods_path(@server), alert: "Save files must have .zip extension"
      return
    end

    filename = uploaded_file.original_filename

    # Extract mod name and version from filename (format: modname_version.zip)
    if filename =~ /^(.+)_([0-9\.]+)\.zip$/
      mod_name = $1
      mod_version = $2
    else
      redirect_to factorio_server_server_mods_path(@server),
        alert: "Invalid mod filename format. Expected: modname_version.zip"
      return
    end

    @server.host_driver.write_mod(@server, filename, uploaded_file)

    server_mod = Mod.new(
      name: mod_name,
      version: mod_version,
      factorio_server: @server)
    if server_mod.save
      redirect_to factorio_server_server_mods_path(@server), notice: "Mod uploaded successfully"
    else
      redirect_to factorio_server_server_mods_path(@server), alert: "Failed to save mod information"
    end
  end

  def destroy
    if @mod.destroy
      redirect_to factorio_server_server_mods_path(@mod.factorio_server), notice: "Mod removed successfully."
    else
      redirect_to factorio_server_server_mods_path(@mod.factorio_server), alert: "Failed to remove mod."
    end
  end

  private

  def set_mod
    @mod = Mod.find(params[:id])
  end

  def server_mod_params
    params.require(:server_mod).permit(:name, :version, :factorio_server_id)
  end
end
