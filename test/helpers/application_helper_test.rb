require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "render_hook is silent when no extension partial exists" do
    assert_nil render_hook("does_not_exist")
  end

  test "render_hook renders an extension partial with locals" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "hooks"))
      File.write(File.join(dir, "hooks", "_badge.html.erb"), "<span><%= label %></span>")

      controller.prepend_view_path(dir)

      assert_equal "<span>pro</span>", render_hook("badge", label: "pro")
    end
  end
end
