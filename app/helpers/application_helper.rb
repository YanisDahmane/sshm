module ApplicationHelper
  # French relative time, e.g. "il y a 3 minutes", "dans 2 heures", "à l'instant".
  # Mirrored by app/javascript/controllers/relative_time_controller.js: keep both in sync.
  def relative_time_in_words(time, now: Time.current)
    seconds = (time - now).round
    return (seconds.positive? ? "dans moins d'une minute" : "à l'instant") if seconds.abs < 60

    minutes = (seconds.abs / 60.0).round
    hours = (minutes / 60.0).round
    words = if minutes < 60 then pluralize(minutes, "minute", plural: "minutes")
    elsif hours < 24 then pluralize(hours, "heure", plural: "heures")
    else pluralize((hours / 24.0).round, "jour", plural: "jours")
    end

    seconds.positive? ? "dans #{words}" : "il y a #{words}"
  end

  # <time> showing `prefix` + the relative time, kept up to date in the browser,
  # with the exact date as tooltip. Once `time` has passed, shows `expired` if given.
  def relative_time_tag(time, prefix: "", expired: nil, **options)
    text = expired && time <= Time.current ? expired : "#{prefix}#{relative_time_in_words(time)}"

    tag.time text, datetime: time.iso8601, title: l(time, format: :long),
                   data: { controller: "relative-time", relative_time_datetime_value: time.iso8601,
                           relative_time_prefix_value: prefix, relative_time_expired_value: expired }.compact,
                   **options
  end

  # Shell command adding the app's public key to ~/.ssh/authorized_keys.
  def ssh_key_install_command(ssh_key)
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '#{ssh_key.public_key}' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
  end

  # Main navigation link, highlighted (and aria-current) when active.
  def nav_link_to(label, path, active:)
    link_to label, path, aria: { current: (active ? "page" : nil) },
                         class: "rounded-md px-3 py-1.5 text-sm font-medium #{active ? "bg-indigo-50 text-indigo-700" : "text-slate-600 hover:bg-slate-100 hover:text-slate-900"}"
  end

  # Entries of the ⌘K quick search: pages, then servers and profiles.
  def command_palette_items
    pages = [
      { label: "Dashboard", url: root_path }, { label: "Serveurs", url: servers_path }, { label: "Profils", url: profiles_path },
      { label: "Paramètres", hint: "clé SSH de SSHM", url: settings_path },
      { label: "Ajouter un serveur", url: new_server_path }, { label: "Ajouter un profil", url: new_profile_path }
    ].map { |page| page.merge(group: "Pages") }

    servers = Server.order(:name).map { |server| { group: "Serveurs", label: server.name, hint: "#{server.username}@#{server.host}", url: server_path(server) } }
    profiles = Profile.order(:name).map { |profile| { group: "Profils", label: profile.name, hint: profile.authorized_key&.comment, url: profile_path(profile) } }

    pages + servers + profiles
  end

  # Profile name proposed for an authorized key: its comment without the host
  # part ("alice@laptop" → "alice"), or nothing for an unnamed key.
  def suggested_profile_name(key)
    key.comment&.split("@")&.first.presence
  end
end
