class ServerLogsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_server

  def index
    @logs = @server.server_logs.order(timestamp: :desc)
  end

  private

  def set_server
    @server = current_user.factorio_servers.find(params[:factorio_server_id])
  end
end
