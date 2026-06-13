class FactorioServersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_server, only: [ :show, :edit, :update, :destroy, :start, :stop, :restart, :console, :update_version ]
  before_action :ensure_server_not_running, only: [ :edit, :update, :destroy, :update_version ]

  def index
    @servers = current_user.factorio_servers
  end

  def show
  end

  def new
    @server = current_user.factorio_servers.build
  end

  def create
    @server = current_user.factorio_servers.build(server_params)

    if @server.save
      redirect_to @server, notice: "Factorio server was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @server.update(server_params)
      redirect_to @server, notice: "Factorio server was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @server.stop if @server.running?
    @server.destroy
    redirect_to factorio_servers_path, notice: "Factorio server was successfully deleted."
  end

  def start
    @server = current_user.factorio_servers.find(params[:id])

    unless @server.host_ready?
      redirect_to @server, alert: @server.host_status_message.presence || "The server host is not ready yet."
      return
    end

    if @server.start
      respond_to do |format|
        format.html { redirect_to @server }
      end
    else
      respond_to do |format|
        format.html { redirect_to @server, alert: "Failed to start server." }
      end
    end
  end

  def stop
    @server = current_user.factorio_servers.find(params[:id])

    if @server.stop
      respond_to do |format|
        format.html { redirect_to @server }
      end
    else
      respond_to do |format|
        format.html { redirect_to @server, alert: "Failed to stop server." }
      end
    end
  end

  def restart
    @server = current_user.factorio_servers.find(params[:id])

    @server.restart

    respond_to do |format|
      format.html { redirect_to @server, notice: "Server is restarting..." }
    end
  end

  def check_updates
    @server = current_user.factorio_servers.find(params[:id])
    @update_info = @server.check_for_updates || {}

    respond_to do |format|
      format.html {
        message = if @update_info[:error]
                    "Error checking for updates: #{@update_info[:error]}"
        elsif @update_info[:update_available]
                    "Update available!"
        else
                    "No updates available."
        end
        redirect_to @server, notice: message
      }
      format.json { render json: @update_info }
    end
  end

  def update_version
    @server = current_user.factorio_servers.find(params[:id])
    result = @server.update_version(params[:version])

    respond_to do |format|
      if result[:success]
        format.html { redirect_to @server, notice: result[:message] }
        format.json { render json: { success: true, message: result[:message] } }
      else
        format.html { redirect_to @server, alert: result[:message] }
        format.json { render json: { success: false, message: result[:message] }, status: :unprocessable_entity }
      end
    end
  end

  def console
    unless @server.running?
      render json: { success: false, error: "Server is not running" }, status: :bad_request
      return
    end

    command = params[:command].to_s.strip
    if command.blank?
      render json: { success: false, error: "No command provided" }, status: :bad_request
      return
    end

    begin
      response = RconService.new(@server.host_driver.rcon_host(@server), @server.rcon_port, @server.rcon_password).execute(command)

      @server.server_logs.create(
        level: "info",
        message: "RCON command executed: #{command}",
        timestamp: Time.current
      )

      render json: { success: true, response: response }
    rescue RconService::RconError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
  end

  private

  def set_server
    @server = current_user.factorio_servers.find(params[:id])
  end

  def server_params
    params.require(:factorio_server).permit(
      :name, :description, :port, :rcon_port, :max_players,
      :game_password, :admin_password, :auto_start, :version, :save_file,
      :visibility_public, :visibility_lan, :require_user_verification,
      :max_upload_in_kilobytes_per_second, :max_upload_slots,
      :minimum_latency_in_ticks, :ignore_player_limit_for_returning_players,
      :allow_commands, :autosave_interval, :autosave_slots,
      :afk_autokick_interval, :auto_pause, :only_admins_can_pause_the_game,
      :autosave_only_on_server, :non_blocking_saving,
      :minimum_segment_size, :minimum_segment_size_peer_count,
      :maximum_segment_size, :maximum_segment_size_peer_count,
      :token, :tags, :enable_elevated_rails, :enable_quality, :enable_space_age,
      :auto_update_mods, :admin_usernames
    )
  end

  def ensure_server_not_running
    if @server.running?
      respond_to do |format|
        format.html {
          redirect_to @server, alert: "Server must be stopped before it can be modified."
        }
        format.json {
          render json: { error: "Server must be stopped before it can be modified." },
          status: :unprocessable_entity
        }
        format.turbo_stream {
          flash.now[:alert] = "Server must be stopped before it can be modified."
          render turbo_stream: turbo_stream.replace("flash", partial: "layouts/flash")
        }
      end
    end
  end
end
