require "test_helper"

class OnboardingChecklistTest < ActiveSupport::TestCase
  def done_keys = OnboardingChecklist.new.steps.select(&:done?).map(&:key)

  test "lists the five setup steps in order" do
    assert_equal %i[ssh_key server install_key inventory public_key], OnboardingChecklist.new.steps.map(&:key)
  end

  test "with the fixtures: key, servers and keys exist, nothing tested nor inventoried" do
    checklist = OnboardingChecklist.new

    assert_equal %i[ssh_key server public_key], done_keys
    assert_equal :install_key, checklist.current.key
    assert_equal 3, checklist.done_count
    assert_not checklist.complete?
  end

  test "from scratch, the current step is generating the key" do
    [ SshKey, Server, PublicKey ].each(&:delete_all)

    assert_empty done_keys
    assert_equal :ssh_key, OnboardingChecklist.new.current.key
  end

  test "the key is installed once a server accepted an SSH login" do
    servers(:db).record_ssh_status!(true)
    assert_includes done_keys, :install_key
  end

  test "the first inventory is done once a server was inventoried" do
    assert_not_includes done_keys, :inventory
    servers(:db).update_columns(inventoried_at: Time.current)
    assert_includes done_keys, :inventory
  end

  test "complete when every step is done" do
    servers(:web).record_ssh_status!(true)
    servers(:web).update_columns(inventoried_at: Time.current)

    checklist = OnboardingChecklist.new
    assert checklist.complete?
    assert_nil checklist.current
  end
end
