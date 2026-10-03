require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "relative_time_in_words in French, past and future" do
    freeze_time do
      assert_equal "à l'instant", relative_time_in_words(30.seconds.ago)
      assert_equal "dans moins d'une minute", relative_time_in_words(30.seconds.from_now)
      assert_equal "il y a 1 minute", relative_time_in_words(1.minute.ago)
      assert_equal "il y a 3 minutes", relative_time_in_words(3.minutes.ago)
      assert_equal "dans 10 minutes", relative_time_in_words(9.minutes.from_now + 30.seconds)
      assert_equal "dans 1 heure", relative_time_in_words(60.minutes.from_now)
      assert_equal "il y a 4 heures", relative_time_in_words(4.hours.ago)
      assert_equal "dans 1 jour", relative_time_in_words(1.day.from_now)
      assert_equal "il y a 7 jours", relative_time_in_words(7.days.ago)
    end
  end

  test "relative_time_tag renders a live <time> with the exact date as tooltip" do
    freeze_time do
      time = 9.minutes.from_now
      render html: relative_time_tag(time, prefix: "Expire ", expired: "Expiré", class: "badge")

      assert_select "time.badge[datetime=?][title=?][data-controller=relative-time]", time.iso8601, I18n.l(time, format: :long), text: "Expire dans 9 minutes" do |element|
        assert_equal "Expire ", element.attr("data-relative-time-prefix-value").to_s
        assert_equal "Expiré", element.attr("data-relative-time-expired-value").to_s
      end
    end
  end

  test "relative_time_tag shows the expired text once the time has passed" do
    render html: relative_time_tag(1.minute.ago, prefix: "Expire ", expired: "Expiré")
    assert_select "time", text: "Expiré"
  end

  test "relative_time_tag without expired text keeps showing the relative time" do
    render html: relative_time_tag(3.minutes.ago)
    assert_select "time:not([data-relative-time-expired-value])", text: "il y a 3 minutes"
  end

  test "command_palette_items lists pages, servers and profiles" do
    items = command_palette_items

    assert_equal %w[Pages Serveurs Profils], items.map { |item| item[:group] }.uniq
    assert_includes items, { group: "Pages", label: "Serveurs", url: servers_path }
    assert_includes items, { group: "Serveurs", label: "Web", hint: "deploy@192.168.1.10", url: server_path(servers(:web)) }
    assert_includes items, { group: "Profils", label: "Alice", hint: "alice@laptop", url: profile_path(profiles(:alice)) }
    assert_includes items, { group: "Profils", label: "CI", hint: nil, url: profile_path(profiles(:ci)) }
  end

  test "ssh_key_install_command appends the public key with strict permissions" do
    assert_equal "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '#{ssh_keys(:main).public_key}' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys",
                 ssh_key_install_command(ssh_keys(:main))
  end

  test "nav_link_to marks the active link" do
    render html: nav_link_to("Serveurs", "/servers", active: true) + nav_link_to("Profils", "/profiles", active: false)

    assert_select "a[href='/servers'][aria-current=page].bg-indigo-50", "Serveurs"
    assert_select "a[href='/profiles']:not([aria-current])", "Profils"
  end

  test "suggested_profile_name drops the host part of the comment" do
    assert_equal "alice", suggested_profile_name(AuthorizedKey.new(type: "ssh-ed25519", key: "AAAA", comment: "alice@laptop"))
    assert_equal "Deploy key", suggested_profile_name(AuthorizedKey.new(type: "ssh-ed25519", key: "AAAA", comment: "Deploy key"))
    assert_nil suggested_profile_name(AuthorizedKey.new(type: "ssh-ed25519", key: "AAAA"))
    assert_nil suggested_profile_name(AuthorizedKey.new(type: "ssh-ed25519", key: "AAAA", comment: "@host"))
  end
end
