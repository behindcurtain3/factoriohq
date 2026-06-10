require "test_helper"

class UpdateModListJobTest < ActiveJob::TestCase
  include TmpFactorioData

  test "writes the mod list with built-in and uploaded mods" do
    server = factorio_servers(:one)
    FileUtils.mkdir_p(server.mods_directory)

    UpdateModListJob.perform_now(server)

    mods = JSON.parse(File.read(server.mod_list_path))["mods"]
    names = mods.map { |mod| mod["name"] }
    assert_includes names, "base"
    assert_includes names, "space-exploration"

    disabled = mods.find { |mod| mod["name"] == "krastorio2" }
    assert_equal false, disabled["enabled"]
  end
end
