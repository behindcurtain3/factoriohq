class SaveFilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_server
  before_action :ensure_server_not_running, only: [ :create, :destroy, :set_as_current ]

  def index
    @save_files = @server.host_driver.list_saves(@server)
  end

  def create
    if params[:save_file].blank?
      redirect_to factorio_server_save_files_path(@server), alert: "No file selected"
      return
    end

    uploaded_file = params[:save_file]
    # Ensure file has .zip extension
    unless uploaded_file.original_filename.end_with?(".zip")
      redirect_to factorio_server_save_files_path(@server), alert: "Save files must have .zip extension"
      return
    end

    @server.host_driver.write_save(@server, uploaded_file.original_filename, uploaded_file)

    redirect_to factorio_server_save_files_path(@server), notice: "Save file uploaded successfully"
  end

  def show
    path = @server.host_driver.save_path_for_download(@server, params[:filename])

    if path
      send_file path, disposition: "attachment"
    else
      redirect_to factorio_server_save_files_path(@server), alert: "Save file not found"
    end
  end

  def destroy
    filename = params[:filename]

    if @server.host_driver.delete_save(@server, filename)
      # If the file being deleted is the current save file, clear the save_file attribute
      @server.update(save_file: nil) if @server.save_file == filename
      redirect_to factorio_server_save_files_path(@server), notice: "Save file deleted successfully"
    else
      redirect_to factorio_server_save_files_path(@server), alert: "Save file not found"
    end
  end

  def set_as_current
    filename = params[:filename]
    if @server.update(save_file: filename)
      redirect_to factorio_server_save_files_path(@server), notice: "#{filename} set as current save file"
    else
      redirect_to factorio_server_save_files_path(@server), alert: "Failed to update save file"
    end
  end

  private

  def set_server
    @server = current_user.factorio_servers.find(params[:factorio_server_id])
  end

  def ensure_server_not_running
    if @server.running?
      redirect_to factorio_server_save_files_path(@server),
        alert: "Server must be stopped before save files can be modified."
    end
  end
end
