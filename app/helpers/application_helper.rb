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

  # "0 ligne", "1 ligne", "2 lignes": in French, 0 and 1 are singular
  # (Rails' pluralize only treats 1 as singular).
  def pluralize_fr(count, singular, plural)
    "#{count} #{count.to_i.abs < 2 ? singular : plural}"
  end

  # Shell command adding the app's public key to ~/.ssh/authorized_keys.
  def ssh_key_install_command(ssh_key)
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '#{ssh_key.public_key}' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
  end

  # Entries of the ⌘K quick search: pages, then servers and public_keys.
  def command_palette_items
    pages = [
      { label: "Vue d'ensemble", url: root_path }, { label: "Parc", hint: "serveurs", url: servers_path }, { label: "Trousseau", hint: "clés SSH", url: public_keys_path },
      { label: "Groupes de serveurs", url: server_groups_path },
      { label: "Activité", url: activities_path }
    ]
    pages += [ { label: "Importer des serveurs", hint: "CSV, ~/.ssh/config", url: new_server_import_path }, { label: "Ajouter un serveur", url: new_server_path }, { label: "Ajouter une clé au trousseau", url: new_public_key_path } ] if can?(:operate)
    pages += [
      { label: "Paramètres", hint: "clé SSH d'Elio", url: settings_path },
      { label: "Notifications", hint: "paramètres", url: settings_notifications_path },
      { label: "Automatisations", hint: "paramètres", url: settings_automations_path }
    ] if can?(:administer)
    pages = pages.map { |page| page.merge(group: "Pages") }

    groups = ServerGroup.order(:name).map { |group| { group: "Groupes", label: group.name, hint: "serveurs du groupe", url: servers_path(group: group.id) } }
    servers = Server.order(:name).includes(:server_groups).map do |server|
      { group: "Serveurs", label: server.name, hint: [ "#{server.username}@#{server.host}", *server.server_groups.map(&:name) ].join(" · "), url: server_path(server) }
    end
    public_keys = PublicKey.order(:name).map { |public_key| { group: "Trousseau", label: public_key.name, hint: public_key.kind_label, url: public_key_path(public_key) } }

    pages + groups + servers + public_keys
  end

  # PublicKey name proposed for an authorized key: its comment without the host
  # part ("alice@laptop" → "alice"), or nothing for an unnamed key.
  def suggested_public_key_name(key)
    key.comment&.split("@")&.first.presence
  end
end
