require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "is valid with an email and a password" do
    user = User.new(email: "valid@example.com", password: "password123")
    assert user.valid?
  end

  test "requires an email" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert user.errors.added?(:email, :blank)
  end

  test "requires a unique email (case insensitive)" do
    user = User.new(email: users(:one).email.upcase, password: "password123")
    assert_not user.valid?
    assert user.errors.added?(:email, :taken, value: users(:one).email)
  end

  test "requires a password of at least 6 characters" do
    user = User.new(email: "short@example.com", password: "12345")
    assert_not user.valid?
    assert user.errors.of_kind?(:password, :too_short)
  end

  test "authenticates with the correct password only" do
    assert users(:one).valid_password?("password123")
    assert_not users(:one).valid_password?("wrong")
  end
end
