require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "can_authenticate_to_factorio_api? needs both username and token" do
    assert users(:one).can_authenticate_to_factorio_api?
    assert_not users(:two).can_authenticate_to_factorio_api?
  end

  test "has many factorio servers" do
    assert_includes users(:one).factorio_servers, factorio_servers(:one)
  end

  test "the first registered user becomes an admin" do
    FactorioServer.destroy_all
    User.destroy_all

    first = User.create!(email: "first@example.com", password: "password123")
    assert first.admin?, "the first user should be made an admin"

    second = User.create!(email: "second@example.com", password: "password123")
    assert_not second.admin?, "subsequent users should not be admins"
  end
end
