class ModsController < ApplicationController
  before_action :authenticate_user!

  def index
    @response = FactorioApi::Client.get_mods(params[:page], 25, true, params[:query])
    @mods = @response.results
  end

  def show
   @mod = FactorioApi::Client.get_mod(params[:id])
   @available_servers = current_user.factorio_servers.where.not(
      id: current_user.factorio_servers.joins(:mods).where(mods: { name: @mod.name }).select(:id)
   )

   @new_mod = Mod.new
  end

  def create
    @server = FactorioServer.find(params[:mod][:factorio_server_id])
    @mod = FactorioApi::Client.get_mod(params[:mod][:name])
    release = @mod.releases.find { |release| release.version == params[:mod][:version] }
    filename = @mod.name + "_" + release.version + ".zip"
    output_path = File.join(@server.mods_directory, filename)

    download_result = FactorioApi::Client.download_mod(release.download_url, current_user.factorio_username, current_user.factorio_token, output_path)

    if download_result[:success]
      sha1 = download_result[:sha1]
      if sha1 != release.sha1
        redirect_to factorio_server_path(@server), alert: "SHA1 mismatch. Mod not added."
        return
      end
    end

    mod = Mod.new(mod_params)
    mod.factorio_server = @server
    if mod.save
      redirect_to factorio_server_path(mod.factorio_server), notice: "Mod added successfully."
    else
      redirect_to mods_path(mod.name), alert: "Failed to add mod."
    end
  end

  def toggle
    @mod = Mod.find(params[:id])
    if @mod.update(enabled: !@mod.enabled)
      redirect_to factorio_server_server_mod_path(@mod.factorio_server), notice: "Mod toggled successfully."
    else
      redirect_to factorio_server_server_mod_path(@mod.factorio_server), alert: "Failed to toggle mod."
    end
  end

  private

  def mod_params
    params.require(:mod).permit(:name, :version, :factorio_server_id)
  end
end
