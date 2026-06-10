require "test_helper"

class ModsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include TmpFactorioData

  Release = Struct.new(:version, :download_url, :sha1)
  PortalMod = Struct.new(:name, :releases)

  setup do
    @server = factorio_servers(:one)
    sign_in users(:one)
  end

  test "create downloads a verified mod and records it" do
    content = "PK\x03\x04mod-bytes"
    release = Release.new("2.0.0", "/download/cool-mod", Digest::SHA1.hexdigest(content))
    portal_mod = PortalMod.new("cool-mod", [ release ])

    stub_method(FactorioApi::Client, :get_mod, ->(_name) { portal_mod }) do
      stub_method(FactorioApi::Client, :download_mod, lambda { |_url, _user, _token, output_path|
        File.binwrite(output_path, content)
        { success: true, sha1: Digest::SHA1.hexdigest(content) }
      }) do
        assert_difference -> { @server.mods.count }, 1 do
          post mods_path, params: { mod: { name: "cool-mod", version: "2.0.0", factorio_server_id: @server.id } }
        end
      end
    end

    assert_redirected_to factorio_server_path(@server)
    assert File.exist?(File.join(@server.mods_directory, "cool-mod_2.0.0.zip"))
  end

  test "cannot install a mod onto another user's server" do
    other_server = factorio_servers(:two)

    assert_no_difference -> { Mod.count } do
      post mods_path, params: { mod: { name: "cool-mod", version: "2.0.0", factorio_server_id: other_server.id } }
    end

    assert_response :not_found
  end

  test "cannot toggle another user's mod" do
    sign_in users(:two)
    mod = mods(:one) # belongs to user one's server

    patch toggle_mod_path(mod)

    assert_response :not_found
    assert mod.reload.enabled
  end

  test "create rejects a download whose checksum does not match" do
    release = Release.new("2.0.0", "/download/cool-mod", "expected-sha1")
    portal_mod = PortalMod.new("cool-mod", [ release ])

    stub_method(FactorioApi::Client, :get_mod, ->(_name) { portal_mod }) do
      stub_method(FactorioApi::Client, :download_mod, lambda { |_url, _user, _token, output_path|
        File.binwrite(output_path, "tampered")
        { success: true, sha1: Digest::SHA1.hexdigest("tampered") }
      }) do
        assert_no_difference -> { Mod.count } do
          post mods_path, params: { mod: { name: "cool-mod", version: "2.0.0", factorio_server_id: @server.id } }
        end
      end
    end

    assert_redirected_to factorio_server_path(@server)
    assert_match "SHA1 mismatch", flash[:alert]
    assert_not File.exist?(File.join(@server.mods_directory, "cool-mod_2.0.0.zip"))
  end
end
