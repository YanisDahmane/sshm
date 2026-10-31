# Shell snippets shared by the scripts that work on an account's authorized_keys.
module Keys::AuthorizedKeysScript
  # Stops on the first error and resolves the home directory.
  def self.prelude(home)
    <<~SH
      set -e
      home=#{home}
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
