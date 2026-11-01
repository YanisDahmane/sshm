# Scheduled tasks of a server, read-only: the system crontabs (/etc/crontab,
# /etc/cron.d/*), the scripts of /etc/cron.{hourly,daily,weekly,monthly}, the
# users' crontabs (root only: partial without it) and the systemd timers, with
# their last run, its result and the next one.
#
# Cron keeps no trace of its runs that Elio could read without logs: only the
# timers can be "failed" or "late": next run overdue, or last run older than
# LATE_FACTOR periods while the machine has been up for a whole period (a
# server that was off catches up after booting: not late).
class Inventory::Collectors::ScheduledTasks < Inventory::Collector
  ENVIRONMENT = /\A[A-Za-z_][A-Za-z0-9_]*\s*=/
  PERIODS = %w[hourly daily weekly monthly].freeze
  # How late a timer may be, in periods (and at least OVERDUE_MARGIN).
  LATE_FACTOR = 2
  OVERDUE_MARGIN = 1.hour

  def collect
    result = run("inventory.scheduled_tasks")
    raise Error, "Lecture des tâches planifiées impossible : #{result.stderr.strip.presence || "code #{result.exit_status}"}" if result.stdout.blank?

    data = self.class.parse(result.stdout)
    return unsupported("Ni cron ni systemd sur ce système") if data["cron"].empty? && data["periodic"].empty? && data["timers"].nil?

    data["timers"] ||= []
    data["user_crontabs"] == "unreadable" ? partial(data, "Crontabs des utilisateurs illisibles : Elio a besoin de root (sudo sans mot de passe).") : ok(data)
  end

  def self.parse(output, now: Time.current)
    sections = sections(output)
    cron = parse_crontab(sections["crontab"], source: "/etc/crontab", system: true) +
           files(sections["cron.d"]).flat_map { |path, body| parse_crontab(body, source: path, system: true) }
    users = sections["users"].strip == "unreadable" ? "unreadable" : "ok"
    cron += files(sections["users"]).flat_map { |user, body| parse_crontab(body, source: "crontab de #{user}", user: user) } if users == "ok"

    uptime = sections["uptime"].to_s.split.first&.to_f
    booted_at = uptime && now - uptime
    { "cron" => cron, "periodic" => parse_periodic(sections["periodic"]), "timers" => parse_timers(sections["timers"], now: now, booted_at: booted_at),
      "user_crontabs" => users }
  end

  # "@@file <name>" blocks → { name => body }.
  def self.files(text)
    text.to_s.split(/^@@file (.+)\n?/).drop(1).each_slice(2).map { |name, body| [ name.strip, body.to_s ] }
  end

  # Crontab lines: "m h dom mon dow [user] command" (the user field only in
  # the system crontabs) or "@daily [user] command"; comments and variables skipped.
  def self.parse_crontab(text, source:, system: false, user: nil)
    text.to_s.lines.filter_map do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#") || line.match?(ENVIRONMENT)

      fields = line.split(/\s+/, line.start_with?("@") ? (system ? 3 : 2) : (system ? 7 : 6))
      schedule_size = line.start_with?("@") ? 1 : 5
      next if fields.size < schedule_size + (system ? 2 : 1)

      schedule = fields.first(schedule_size).join(" ")
      owner = system ? fields[schedule_size] : user
      { "source" => source, "user" => owner, "schedule" => schedule, "command" => fields.last.strip }
    end
  end

  # "daily logrotate" → { "period" => "daily", "name" => "logrotate" }
  def self.parse_periodic(text)
    text.to_s.lines.filter_map do |line|
      period, name = line.split(" ", 2).map(&:strip)
      { "period" => period, "name" => name } if period.in?(PERIODS) && name.present?
    end
  end

  # Blocks of `systemctl show` (timer, then its service prefixed "Service"),
  # separated by blank lines. nil without systemd.
  def self.parse_timers(text, now:, booted_at: nil)
    return if text.strip == "unsupported"

    text.split(/\n\s*\n/).filter_map do |block|
      properties = Hash.new { |hash, key| hash[key] = [] }
      block.lines.each do |line|
        key, value = line.chomp.split("=", 2)
        properties[key] << value.to_s if key.present? && value
      end
      name = properties["Id"].first
      next unless name&.end_with?(".timer")

      schedules = (properties["TimersCalendar"] + properties["TimersMonotonic"]).filter_map { |value| value[/\{\s*(\w+=[^;}]+?)\s*;/, 1] }
      last_at = timestamp(properties["LastTriggerUSec"].first)
      next_at = timestamp(properties["NextElapseUSecRealtime"].first)
      result = properties["ServiceResult"].first.presence
      timer = { "name" => name, "unit" => properties["Unit"].first.presence, "description" => properties["Description"].first.presence,
                "active" => properties["ActiveState"].first, "enabled" => properties["UnitFileState"].first.presence, "schedules" => schedules,
                "last_at" => last_at&.iso8601, "next_at" => next_at&.iso8601, "result" => result,
                "exit_status" => properties["ServiceExecMainStatus"].first&.to_i }
      timer["failed"] = true if last_at && result && result != "success"
      timer["late"] = true if late?(schedules, last_at, next_at, timer["active"], now, booted_at)
      timer.compact
    end
  end

  # "@1730437200" (--timestamp=unix) or "Fri 2026-11-01 06:00:00 CET"; "n/a" or "" → nil.
  def self.timestamp(value)
    return if value.blank? || value == "n/a" || value == "0"
    return Time.zone.at(value.delete_prefix("@").to_i) if value.start_with?("@")

    Time.zone.parse(value)
  rescue ArgumentError
    nil
  end

  def self.late?(schedules, last_at, next_at, active, now, booted_at)
    return false unless active == "active"
    return true if next_at && next_at < now - OVERDUE_MARGIN

    period = schedules.filter_map { |schedule| Inventory::CronSchedule.timer(schedule).period }.min
    return false unless period.present? && last_at.present?
    return false if booted_at && booted_at > now - period # just booted: systemd catches up

    last_at < now - [ period * LATE_FACTOR, OVERDUE_MARGIN ].max
  end

  def self.changes(previous, data)
    flagged = ->(timers, flag) { Array(timers).select { |timer| timer[flag] }.map { |timer| timer["name"] }.to_set }
    (flagged.(data["timers"], "failed") - flagged.(previous["timers"], "failed")).sort.map { |name| { kind: :scheduled_task_failed, data: { task: name } } } +
      (flagged.(data["timers"], "late") - flagged.(previous["timers"], "late")).sort.map { |name| { kind: :scheduled_task_late, data: { task: name } } }
  end
end
