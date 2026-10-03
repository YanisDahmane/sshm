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

  test "new users are viewers by default" do
    assert User.new.viewer?
  end

  test "rejects an unknown role" do
    user = User.new(email: "x@example.com", password: "password123", role: "root")
    assert_not user.valid?
    assert user.errors.key?(:role)
  end

  test "permissions per role" do
    assert_equal [ true, true, true ], %i[view operate administer].map { |permission| users(:one).can?(permission) }
    assert_equal [ true, true, false ], %i[view operate administer].map { |permission| users(:operator).can?(permission) }
    assert_equal [ true, false, false ], %i[view operate administer].map { |permission| users(:viewer).can?(permission) }
    assert_raises(KeyError) { users(:one).can?(:nope) }
  end

  test "role labels" do
    assert_equal %w[Admin Opérateur Lecture], [ users(:one), users(:operator), users(:viewer) ].map(&:role_label)
  end

  test "a deactivated account cannot authenticate" do
    user = users(:operator)
    assert user.active_for_authentication?

    user.deactivate!

    assert user.deactivated?
    assert_not user.active_for_authentication?
    assert_equal :deactivated, user.inactive_message
    assert_not_includes User.active, user

    user.reactivate!
    assert user.active_for_authentication?
  end

  test "the last active admin cannot be demoted or deactivated" do
    admin = users(:one)

    assert_not admin.update(role: :operator)
    assert_includes admin.errors.full_messages, "Il doit toujours rester au moins un administrateur actif."

    admin.reload
    assert_raises(ActiveRecord::RecordInvalid) { admin.deactivate! }
  end

  test "an admin can be demoted when another active admin remains" do
    users(:operator).update!(role: :admin)

    assert users(:one).update(role: :viewer)
  end

  test "a deactivated admin does not count as remaining admin" do
    other = users(:operator)
    other.update!(role: :admin)
    other.deactivate!

    assert_not users(:one).update(role: :viewer)
  end

  test "a profile belongs to one user at most" do
    users(:operator).update!(profile: profiles(:alice))

    user = users(:viewer)
    assert_not user.update(profile: profiles(:alice))
    assert user.errors.of_kind?(:profile_id, :taken)
  end

  test "deleting a profile unlinks its user" do
    users(:operator).update!(profile: profiles(:alice))
    profiles(:alice).destroy!

    assert_nil users(:operator).reload.profile_id
  end
end
