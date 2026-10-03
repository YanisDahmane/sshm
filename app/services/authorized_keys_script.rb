# Common start of the shell scripts that work on an account's authorized_keys:
# resolves the home directory and stops with "unknown user" when `~user`
# could not be expanded (the user does not exist).
module AuthorizedKeysScript
  def self.prelude(home)
    <<~SH
      set -e
      home=#{home}
      case "$home" in "~"*|"") echo "unknown user" >&2; exit 3 ;; esac
    SH
  end
end
