require "test_helper"

class AccessRuleTest < ActiveSupport::TestCase
  test "needs exactly one subject (profile or team) and one target (server or group)" do
    assert AccessRule.new(profile: profiles(:alice), server: servers(:web)).valid?
    assert AccessRule.new(team: teams(:developers), server_group: server_groups(:production)).valid?

    rule = AccessRule.new
    assert_not rule.valid?
    assert rule.errors.key?(:subject_key)
    assert rule.errors.key?(:target_key)

    assert_not AccessRule.new(profile: profiles(:alice), team: teams(:developers), server: servers(:web)).valid?
    assert_not AccessRule.new(profile: profiles(:alice), server: servers(:web), server_group: server_groups(:production)).valid?
  end

  test "the database enforces one subject and one target too" do
    assert_raises(ActiveRecord::StatementInvalid) do
      AccessRule.new(profile: profiles(:alice), team: teams(:developers), server: servers(:web)).save!(validate: false)
    end
  end

  test "subject_key and target_key read and write the form values" do
    rule = AccessRule.new(subject_key: "team:#{teams(:developers).id}", target_key: "server_group:#{server_groups(:production).id}")
    assert_equal teams(:developers), rule.subject
    assert_equal server_groups(:production), rule.target
    assert_equal "team:#{teams(:developers).id}", rule.subject_key

    rule.subject_key = "profile:#{profiles(:ci).id}"
    rule.target_key = "server:#{servers(:db).id}"
    assert_nil rule.team_id
    assert_nil rule.server_group_id
    assert_equal [ profiles(:ci), servers(:db) ], [ rule.subject, rule.target ]

    rule.subject_key = "user:1"
    assert_nil rule.subject
  end

  test "the account is the login user (blank) or a valid Unix name" do
    assert_nil AccessRule.new(unix_user: "  ").unix_user
    assert AccessRule.new(profile: profiles(:alice), server: servers(:web), unix_user: " debian ").tap(&:validate).errors.empty?
    assert_not AccessRule.new(profile: profiles(:alice), server: servers(:web), unix_user: "bad name;").valid?
  end

  test "refuses a duplicate rule, but the same rule on another account is fine" do
    AccessRule.create!(profile: profiles(:alice), server: servers(:web))

    duplicate = AccessRule.new(profile: profiles(:alice), server: servers(:web))
    assert_not duplicate.valid?
    assert_includes duplicate.errors.full_messages, "Cette règle existe déjà"
    assert AccessRule.new(profile: profiles(:alice), server: servers(:web), unix_user: "root").valid?
  end

  test "summary, profiles, servers and accounts" do
    rule = AccessRule.new(team: teams(:developers), server_group: server_groups(:production))
    assert_equal "Développeurs → Production (utilisateur SSH)", rule.summary
    assert_equal [ profiles(:alice), profiles(:ci) ], rule.profiles
    assert_equal [ servers(:db), servers(:web) ], rule.servers
    assert_equal "admin", rule.account_for(servers(:db)).unix_user

    rule.unix_user = "debian"
    assert_equal "debian", rule.account_for(servers(:db)).unix_user
    assert_equal "Développeurs → Production (debian)", rule.summary
  end

  test "expectations expand teams and groups into keys per account" do
    AccessRule.create!(team: teams(:developers), server_group: server_groups(:production))
    AccessRule.create!(profile: profiles(:alice), server: servers(:backup), unix_user: "debian")

    expectations = AccessRule.expectations

    assert_equal [ [ servers(:backup), "debian" ], [ servers(:db), "admin" ], [ servers(:web), "deploy" ] ].sort_by { |server, _| server.name },
                 expectations.keys.sort_by { |server, _| server.name }
    assert_equal({ profiles(:alice).fingerprint => profiles(:alice), profiles(:ci).fingerprint => profiles(:ci) }, expectations[[ servers(:web), "deploy" ]])
    assert_equal [ profiles(:alice).fingerprint ], expectations[[ servers(:backup), "debian" ]].keys
  end

  test "rules go away with their profile, team, server or group" do
    AccessRule.create!(profile: profiles(:alice), server: servers(:web))
    AccessRule.create!(team: teams(:developers), server_group: server_groups(:production))
    AccessRule.create!(profile: profiles(:ci), server: servers(:backup))

    profiles(:alice).destroy!
    server_groups(:production).destroy!
    servers(:backup).destroy!
    assert_equal 0, AccessRule.count
  end
end
