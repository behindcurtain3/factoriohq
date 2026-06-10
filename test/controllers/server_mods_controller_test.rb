require "test_helper"

class ServerModsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  include TmpFactorioData

  setup do
    @server = factorio_servers(:one)
    sign_in users(:one)
  end

  test "index lists the server's mods" do
    get factorio_server_server_mods_path(@server)

    assert_response :success
    assert_match "space-exploration", @response.body
  end

  test "create uploads a mod and records it" do
    assert_difference -> { @server.mods.count }, 1 do
      post factorio_server_server_mods_path(@server),
           params: { mod_file: uploaded_mod("cool-mod_1.2.3.zip") }
    end

    assert_redirected_to factorio_server_server_mods_path(@server)
    assert File.exist?(File.join(@server.mods_directory, "cool-mod_1.2.3.zip"))

    mod = @server.mods.order(:created_at).last
    assert_equal "cool-mod", mod.name
    assert_equal "1.2.3", mod.version
  end

  test "create rejects filenames without a name_version pattern" do
    assert_no_difference -> { @server.mods.count } do
      post factorio_server_server_mods_path(@server),
           params: { mod_file: uploaded_mod("badname.zip") }
    end

    assert_redirected_to factorio_server_server_mods_path(@server)
    assert_match "Invalid mod filename", flash[:alert]
  end

  test "create rejects non-zip files" do
    assert_no_difference -> { @server.mods.count } do
      post factorio_server_server_mods_path(@server),
           params: { mod_file: uploaded_mod("cool-mod_1.2.3.tar") }
    end

    assert_redirected_to factorio_server_server_mods_path(@server)
    assert_match "zip", flash[:alert]
  end

  test "create is refused while the server is running" do
    sign_in users(:two)
    running = factorio_servers(:two)

    assert_no_difference -> { Mod.count } do
      post factorio_server_server_mods_path(running),
           params: { mod_file: uploaded_mod("cool-mod_1.2.3.zip") }
    end

    assert_redirected_to factorio_server_server_mods_path(running)
    assert_match "running", flash[:alert]
  end

  test "cannot delete another user's mod" do
    sign_in users(:two)
    mod = mods(:one) # belongs to user one's server

    assert_no_difference -> { Mod.count } do
      delete factorio_server_server_mod_path(@server, mod)
    end

    assert_response :not_found
  end

  test "destroy removes the mod and schedules file deletion" do
    mod = mods(:one)

    assert_difference -> { Mod.count }, -1 do
      delete factorio_server_server_mod_path(@server, mod)
    end

    assert_enqueued_with(job: DeleteModJob, args: [ @server, mod.filename ])
    assert_redirected_to factorio_server_server_mods_path(@server)
  end

  private

  def uploaded_mod(filename)
    path = File.join(@factorio_data_dir, filename)
    File.binwrite(path, "PK\x03\x04")
    Rack::Test::UploadedFile.new(path, "application/zip")
  end
end
