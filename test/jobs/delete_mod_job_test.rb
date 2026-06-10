require "test_helper"

class DeleteModJobTest < ActiveJob::TestCase
  include TmpFactorioData

  test "deletes the mod file from the mods directory" do
    server = factorio_servers(:one)
    FileUtils.mkdir_p(local_host.mods_directory(server))
    path = File.join(local_host.mods_directory(server), "cool-mod_1.2.3.zip")
    File.binwrite(path, "PK\x03\x04")

    DeleteModJob.perform_now(server, "cool-mod_1.2.3.zip")

    assert_not File.exist?(path)
  end

  test "is a no-op when the file is already gone" do
    server = factorio_servers(:one)

    assert_nothing_raised do
      DeleteModJob.perform_now(server, "missing.zip")
    end
  end
end
