require "test_helper"

class SaveFilesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  include TmpFactorioData

  setup do
    @server = factorio_servers(:one)
    sign_in users(:one)
  end

  test "redirects guests to sign in" do
    sign_out users(:one)
    get factorio_server_save_files_path(@server)
    assert_redirected_to new_user_session_path
  end

  test "cannot access another user's save files" do
    get factorio_server_save_files_path(factorio_servers(:two))
    assert_response :not_found
  end

  test "index lists existing save files" do
    write_save("world.zip")

    get factorio_server_save_files_path(@server)

    assert_response :success
    assert_match "world.zip", @response.body
  end

  test "create uploads a save file into the saves directory" do
    post factorio_server_save_files_path(@server),
         params: { save_file: uploaded_zip("new-map.zip") }

    assert_redirected_to factorio_server_save_files_path(@server)
    assert File.exist?(File.join(@server.saves_directory, "new-map.zip"))
  end

  test "create rejects files without a .zip extension" do
    post factorio_server_save_files_path(@server),
         params: { save_file: uploaded_zip("not-a-save.txt") }

    assert_redirected_to factorio_server_save_files_path(@server)
    assert_match "zip", flash[:alert]
    assert_not File.exist?(File.join(@server.saves_directory, "not-a-save.txt"))
  end

  test "create rejects a missing file" do
    post factorio_server_save_files_path(@server)

    assert_redirected_to factorio_server_save_files_path(@server)
    assert_equal "No file selected", flash[:alert]
  end

  test "create is refused while the server is running" do
    sign_in users(:two)
    running = factorio_servers(:two)

    post factorio_server_save_files_path(running),
         params: { save_file: uploaded_zip("map.zip") }

    assert_redirected_to factorio_server_save_files_path(running)
    assert_match "stopped", flash[:alert]
    assert_not File.exist?(File.join(running.saves_directory, "map.zip"))
  end

  test "show downloads a save file" do
    write_save("world.zip", "save-bytes")

    get download_factorio_server_save_files_path(@server, "world.zip")

    assert_response :success
    assert_equal "save-bytes", @response.body
  end

  test "show redirects when the save file does not exist" do
    get download_factorio_server_save_files_path(@server, "missing.zip")

    assert_redirected_to factorio_server_save_files_path(@server)
    assert_match "not found", flash[:alert]
  end

  test "destroy deletes the save file" do
    write_save("world.zip")

    delete delete_factorio_server_save_files_path(@server, "world.zip")

    assert_redirected_to factorio_server_save_files_path(@server)
    assert_not File.exist?(File.join(@server.saves_directory, "world.zip"))
  end

  test "destroy clears save_file when deleting the current save" do
    write_save("world.zip")
    @server.update!(save_file: "world.zip")

    delete delete_factorio_server_save_files_path(@server, "world.zip")

    assert_nil @server.reload.save_file
  end

  test "set_as_current marks a save as the one to load next" do
    post set_current_factorio_server_save_files_path(@server, "world.zip")

    assert_redirected_to factorio_server_save_files_path(@server)
    assert_equal "world.zip", @server.reload.save_file
  end

  private

  def write_save(filename, content = "PK\x03\x04")
    FileUtils.mkdir_p(@server.saves_directory)
    File.binwrite(File.join(@server.saves_directory, filename), content)
  end

  def uploaded_zip(filename)
    path = File.join(@factorio_data_dir, filename)
    File.binwrite(path, "PK\x03\x04")
    Rack::Test::UploadedFile.new(path, "application/zip")
  end
end
