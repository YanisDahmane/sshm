require "test_helper"

class OnboardingChecklistTest < ActiveSupport::TestCase
  def done_keys = OnboardingChecklist.new.steps.select(&:done?).map(&:key)

  test "lists the five setup steps in order" do
    assert_equal %i[ssh_key server install_key profile authorize], OnboardingChecklist.new.steps.map(&:key)
  end

  test "with the fixtures: key, servers and profiles exist, nothing tested nor authorized" do
    checklist = OnboardingChecklist.new

    assert_equal %i[ssh_key server profile], done_keys
    assert_equal :install_key, checklist.current.key
    assert_equal 3, checklist.done_count
    assert_not checklist.complete?
  end

  test "from scratch, the current step is generating the key" do
    [ SshKey, Server, Profile ].each(&:delete_all)

    assert_empty done_keys
    assert_equal :ssh_key, OnboardingChecklist.new.current.key
  end

  test "the key is installed once a server accepted an SSH login" do
    servers(:db).record_ssh_status!(true)
    assert_includes done_keys, :install_key
  end

  test "a profile is authorized once its key is seen on a server" do
    AccountSnapshot.record!(servers(:web), AuthorizedKeysAccount.login(servers(:web)), AuthorizedKey.parse(ssh_keys(:main).public_key))
    assert_not_includes done_keys, :authorize

    AccountSnapshot.record!(servers(:db), AuthorizedKeysAccount.login(servers(:db)), AuthorizedKey.parse(profiles(:ci).public_key))
    assert_includes done_keys, :authorize
  end

  test "complete when every step is done" do
    servers(:web).record_ssh_status!(true)
    AccountSnapshot.record!(servers(:web), AuthorizedKeysAccount.login(servers(:web)), AuthorizedKey.parse(profiles(:alice).public_key))

    checklist = OnboardingChecklist.new
    assert checklist.complete?
    assert_nil checklist.current
  end
end
