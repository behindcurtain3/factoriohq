class SaveFilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_server
  before_action :ensure_server_not_running, only: [ :create, :destroy, :set_as_current ]

  def index
    @save_files = list_save_files
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

    # Save file to server's saves directory
    filename = uploaded_file.original_filename
    file_path = File.join(@server.saves_directory, filename)

    # Create directory if it doesn't exist
    FileUtils.mkdir_p(@server.saves_directory) unless Dir.exist?(@server.saves_directory)

    # Write file
    File.binwrite(file_path, uploaded_file.read)

    redirect_to factorio_server_save_files_path(@server), notice: "Save file uploaded successfully"
  end

  def show
    filename = params[:filename]
    file_path = File.join(@server.saves_directory, filename)

    if File.exist?(file_path)
      send_file file_path, disposition: "attachment"
    else
      redirect_to factorio_server_save_files_path(@server), alert: "Save file not found"
    end
  end

  def destroy
    filename = params[:filename]
    file_path = File.join(@server.saves_directory, filename)

    if File.exist?(file_path)
      # If the file being deleted is the current save file, clear the save_file attribute
      if @server.save_file == filename
        @server.update(save_file: nil)
      end
      File.delete(file_path)
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

  def list_save_files
    Dir.glob(File.join(@server.saves_directory, "*.zip")).map do |file|
      {
        name: File.basename(file),
        size: File.size(file),
        modified: File.mtime(file)
      }
    end.sort_by { |file| file[:modified] }.reverse
  end

  def ensure_server_not_running
    if @server.running?
      redirect_to factorio_server_save_files_path(@server),
        alert: "Server must be stopped before save files can be modified."
    end
  end
end
