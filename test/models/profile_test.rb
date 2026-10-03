require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  setup do
    @key = SshKeyGenerator.generate(comment: "bob@desktop")
  end

  def build_profile(**attributes)
    Profile.new({ name: "Bob", public_key: @key.public_key }.merge(attributes))
  end

  test "fixtures are valid" do
    assert profiles(:alice).valid?
    assert profiles(:ci).valid?
  end

  test "is valid with a name and a public key" do
    assert build_profile.valid?
  end

  test "requires a name and a public key" do
    profile = Profile.new
    assert_not profile.valid?
    assert profile.errors.added?(:name, :blank)
    assert profile.errors.added?(:public_key, :blank)
  end

  test "name is unique, case insensitive" do
    profile = build_profile(name: "alice")
    assert_not profile.valid?
    assert profile.errors.of_kind?(:name, :taken)
  end

  test "squishes the name and strips the public key" do
    profile = build_profile(name: "  Bob   Martin ", public_key: "\n  #{@key.public_key}  \n")
    assert_equal "Bob Martin", profile.name
    assert_equal @key.public_key, profile.public_key
  end

  test "computes the fingerprint from the public key" do
    profile = build_profile
    profile.validate
    assert_equal @key.fingerprint, profile.fingerprint
  end

  test "accepts a public key without a comment" do
    assert build_profile(public_key: @key.public_key.split(" ").first(2).join(" ")).valid?
  end

  test "accepts RSA and ECDSA public keys" do
    [ OpenSSL::PKey::RSA.generate(2048), OpenSSL::PKey::EC.generate("prime256v1") ].each do |pkey|
      profile = build_profile(public_key: "#{pkey.ssh_type} #{[ pkey.to_blob ].pack("m0")} key")
      assert profile.valid?, "#{pkey.ssh_type} should be valid: #{profile.errors.full_messages}"
    end
  end

  test "rejects garbage" do
    profile = build_profile(public_key: "not a key")
    assert_not profile.valid?
    assert profile.errors.added?(:public_key, :invalid)
    assert_nil profile.fingerprint
  end

  test "rejects several keys" do
    other = SshKeyGenerator.generate.public_key
    profile = build_profile(public_key: "#{@key.public_key}\n#{other}")
    assert_not profile.valid?
    assert profile.errors.added?(:public_key, :invalid)
  end

  test "rejects a key with authorized_keys options" do
    profile = build_profile(public_key: %(no-pty #{@key.public_key}))
    assert_not profile.valid?
    assert profile.errors.added?(:public_key, :invalid)
  end

  test "rejects a private key with an explicit message" do
    profile = build_profile(public_key: @key.private_key)
    assert_not profile.valid?
    assert profile.errors.added?(:public_key, :private_key)
    assert_match "private key", profile.errors.full_messages.to_sentence
  end

  test "rejects a key already used by another profile, whatever its comment" do
    type, blob = profiles(:alice).public_key.split(" ")
    profile = build_profile(public_key: "#{type} #{blob} renamed")
    assert_not profile.valid?
    assert profile.errors.of_kind?(:fingerprint, :taken)
  end

  test "rejects the SSHM key" do
    profile = build_profile(public_key: ssh_keys(:main).public_key)
    assert_not profile.valid?
    assert profile.errors.added?(:public_key, :app_key)
  end

  test "authorized_key returns the parsed key" do
    key = profiles(:alice).authorized_key
    assert_equal "alice@laptop", key.name
    assert_equal profiles(:alice).fingerprint, key.fingerprint
  end

  test "authorized_key is nil for an invalid key" do
    assert_nil build_profile(public_key: "nope").authorized_key
  end

  test "the database enforces unique names and fingerprints" do
    duplicate = profiles(:alice).dup
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
