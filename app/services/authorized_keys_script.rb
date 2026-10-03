# Shell snippets shared by the scripts that work on an account's authorized_keys.
module AuthorizedKeysScript
  # Resolves the home directory and stops with "unknown user" when `~user`
  # could not be expanded (the user does not exist).
  def self.prelude(home)
    <<~SH
      set -e
      home=#{home}
      case "$home" in "~"*|"") echo "unknown user" >&2; exit 3 ;; esac
    SH
  end

  # Rewrites "$file" in place (keeping owner and permissions) without the
  # lines holding `escaped_blob` as one of their fields.
  def self.drop_lines(escaped_blob)
    <<~SH
      tmp=$(mktemp "$home/.ssh/authorized_keys.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      awk -v blob=#{escaped_blob} '{ for (i = 1; i <= NF; i++) if ($i == blob) next; print }' "$file" > "$tmp"
      cat "$tmp" > "$file"
    SH
  end
end
