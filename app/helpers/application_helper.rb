module ApplicationHelper
  # Settings of the instance, read once per page.
  def app_settings = @app_settings ||= AppSetting.current

  # [name, id] of every server, for the "attach to" menus of long lists (read once per page).
  def server_options = @server_options ||= Server.order(:name).pluck(:name, :id)

  # Form options of the ping buttons of the fleet: the badge(s) show
  # "Vérification…" while the request runs (server_ping_controller.js).
  def server_ping_form(badge_id = nil)
    { data: { controller: "quiet-submit", action: "turbo:submit-start->server-ping#start turbo:submit-end->server-ping#finish", server_ping_badge_param: badge_id }.compact }
  end

  # Status filters as pills (activity, tasks, keyring, probes…).
  def filter_pill(label, path, active:, count: nil, **options)
    classes = "rounded-full px-3 py-1 text-sm font-medium ring-1 ring-inset #{active ? "bg-accent-fill text-white ring-accent-fill" : "bg-surface text-ink-2 ring-line hover:bg-subtle"}"
    link_to path, class: classes, aria: { current: (active ? "page" : nil) }, **options do
      safe_join([ label, (tag.span(" #{count}", class: "tabular-nums opacity-70") if count) ].compact)
    end
  end
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

  SERVER_TAB_LABELS = { "packages" => "Paquets", "vulnerabilities" => "Vulnérabilités", "services" => "Services", "docker" => "Docker", "schedules" => "Tâches planifiées", "ports" => "Ports", "keys" => "Clés SSH", "history" => "Historique" }.freeze

  # Entries of the ⌘K quick search: pages, groups, servers (`server: true`:
  # the browser derives their tabs from SERVER_TAB_LABELS once something is
  # typed, so a big fleet does not weigh on every page) and keyring keys.
  def command_palette_items
    pages = [
      { label: "Vue d'ensemble", url: root_path }, { label: "Parc", hint: "serveurs", url: servers_path }, { label: "Paquets", hint: "recherche sur tout le parc", url: packages_path }, { label: "Ports", hint: "ports publics du parc", url: ports_path }, { label: "Tâches planifiées", hint: "cron et timers du parc", url: scheduled_tasks_path }, { label: "Vulnérabilités", hint: "CVE du parc", url: vulnerabilities_path }, { label: "Docker", hint: "conteneurs et images du parc", url: docker_path }, { label: "Trousseau", hint: "clés SSH", url: public_keys_path },
      { label: "Groupes de serveurs", url: server_groups_path },
      { label: "Activité", url: activities_path },
      { label: "Tâches", hint: "inventaires et scans en arrière-plan", url: tasks_path },
      *Integration.sidebar_links.map { |link| { label: link[:label], hint: "extension", url: public_send(link[:path]) } }
    ]
    pages += [ { label: "Importer des serveurs", hint: "CSV, ~/.ssh/config", url: new_server_import_path }, { label: "Ajouter un serveur", url: new_server_path }, { label: "Ajouter une clé au trousseau", url: new_public_key_path } ] if can?(:operate)
    pages += [
      { label: "Paramètres", hint: "clé SSH d'Elio", url: settings_path },
      { label: "Notifications", hint: "paramètres", url: settings_notifications_path },
      { label: "Automatisations", hint: "collectes planifiées", url: settings_automations_path },
      { label: "Bases de vulnérabilités", hint: "paramètres, import", url: settings_vulnerabilities_path },
      { label: "Docker", hint: "paramètres, alertes, registres", url: settings_docker_path },
      { label: "Suivi technique des jobs", hint: "Mission Control", url: "/jobs" }
    ] if can?(:administer)
    pages = pages.map { |page| page.merge(group: "Pages") }

    groups = ServerGroup.order(:name).map { |group| { group: "Groupes", label: group.name, hint: "serveurs du groupe", url: servers_path(group: group.id) } }
    servers = Server.order(:name).includes(:server_groups, :inventory_snapshots).map do |server|
      { group: "Serveurs", label: server.name, hint: [ "#{server.username}@#{server.host}", server.distinct_hostname, *server.server_groups.map(&:name) ].compact.join(" · "),
        url: server_path(server), keywords: ([ server.hostname ] + server.addresses).compact.uniq.join(" ").presence, server: true }.compact
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
