# A cron schedule ("*/5 * * * *", "@daily", systemd "OnCalendar=…" or
# "OnUnitActiveSec=1d") described in the reader's language ("every 5
# minutes", "tous les jours à 3 h 00"), with its period in seconds when it is
# regular (used to tell a late timer). Unusual expressions are shown as they
# are. The texts are the cron.* keys (config/locales/<language>/inventory.yml);
# the day names and list connectors come from rails-i18n.
class Inventory::CronSchedule
  # [text, period]: a text is a cron.* key, with a time (midnight) when it has %{at}.
  NICKNAMES = { "@reboot" => [ :at_boot, nil ], "@hourly" => [ :every_hour, 1.hour ], "@daily" => [ :daily, 1.day ],
                "@midnight" => [ :daily, 1.day ], "@weekly" => [ :weekly, 1.week ],
                "@monthly" => [ :monthly, 1.month ], "@yearly" => [ :yearly, 1.year ],
                "@annually" => [ :yearly, 1.year ] }.freeze
  DAY_NAMES = { "sun" => 0, "mon" => 1, "tue" => 2, "wed" => 3, "thu" => 4, "fri" => 5, "sat" => 6 }.freeze
  # systemd shorthands of OnCalendar=.
  CALENDAR_NICKNAMES = { "minutely" => [ :every_minute, 1.minute ], "hourly" => [ :every_hour, 1.hour ],
                         "daily" => [ :daily, 1.day ], "weekly" => [ :weekly_monday, 1.week ],
                         "monthly" => [ :monthly, 1.month ], "yearly" => [ :yearly, 1.year ],
                         "annually" => [ :yearly, 1.year ], "quarterly" => [ :quarterly, 3.months ],
                         "semiannually" => [ :semiannually, 6.months ] }.freeze
  MONOTONIC = { "OnBootSec" => :boot, "OnStartupSec" => :boot, "OnActiveSec" => :activation,
                "OnUnitActiveSec" => :last_start, "OnUnitInactiveSec" => :last_end }.freeze
  SPAN_UNITS = { "us" => 1e-6, "ms" => 1e-3, "s" => 1, "sec" => 1, "second" => 1, "seconds" => 1, "m" => 60, "min" => 60, "minute" => 60, "minutes" => 60,
                 "h" => 3600, "hr" => 3600, "hour" => 3600, "hours" => 3600, "d" => 86_400, "day" => 86_400, "days" => 86_400,
                 "w" => 604_800, "week" => 604_800, "weeks" => 604_800, "month" => 2_629_800, "months" => 2_629_800, "y" => 31_557_600, "year" => 31_557_600 }.freeze

  attr_reader :expression, :text, :period

  def self.cron(expression) = new(expression).tap(&:describe_cron)

  # One "OnCalendar=…" / "OnUnitActiveSec=…" line of a timer.
  def self.timer(setting) = new(setting).tap(&:describe_timer)

  # "1d", "1h 30min", "15min" → seconds (nil when unreadable).
  def self.span(text)
    parts = text.to_s.scan(/(\d+(?:\.\d+)?)\s*([a-z]*)/i)
    return if parts.empty? || text.to_s.gsub(/\d+(?:\.\d+)?\s*[a-z]*/i, "").strip.present?

    parts.sum { |number, unit| number.to_f * SPAN_UNITS.fetch(unit.downcase.presence || "s") { return nil } }.round
  end

  def initialize(expression)
    @expression = expression.to_s.strip
    @text = @expression
  end

  def describe_cron
    if (nickname = NICKNAMES[@expression.downcase])
      @text, @period = nickname_text(nickname)
      return
    end

    minute, hour, day, month, weekday = @expression.split
    return unless weekday

    @text, @period = describe_fields(minute, hour, day, month, weekday) || [ quoted(@expression), nil ]
  end

  def describe_timer
    key, value = @expression.split("=", 2)
    return unless value

    key = key.sub(/USec\z/, "Sec") # `systemctl show` writes OnUnitActiveUSec=1d

    if key == "OnCalendar"
      @text, @period = describe_calendar(value.strip)
    elsif MONOTONIC.key?(key) && (seconds = self.class.span(value))
      @text = t("after.#{MONOTONIC[key]}", span: human_span(seconds))
      @period = seconds if key.in?(%w[OnUnitActiveSec OnUnitInactiveSec])
    end
  end

  def to_s = text

  private

  def t(key, **options) = I18n.t("cron.#{key}", **options)

  def nickname_text((key, period)) = [ t(key, at: at_times([ 0 ], "0")), period ]

  def quoted(value) = t(:quoted, expression: value)

  def describe_fields(minute, hour, day, month, weekday)
    return [ t(:every_minute), 1.minute ] if [ minute, hour, day, month, weekday ].all?("*")
    return unless [ day, month ].all?("*") || weekday == "*"

    if hour == "*" && [ day, month, weekday ].all?("*")
      step = minute[%r{\A\*/(\d+)\z}, 1]&.to_i
      return [ step == 1 ? t(:every_minute) : t(:every_minutes, count: step), step.minutes ] if step&.positive?
      if (offset = minute.match(%r{\A(\d+)(?:-\d+)?/(\d+)\z})) && offset[2].to_i.positive?
        return [ t(:every_minutes_from, count: offset[2].to_i, minute: offset[1].rjust(2, "0")), offset[2].to_i.minutes ]
      end
      return [ t(:every_hour_at, minute: minute.rjust(2, "0")), 1.hour ] if minute.match?(/\A\d+\z/)

      return
    end
    return unless minute.match?(/\A\d+\z/)

    if (step = hour[%r{\A\*/(\d+)\z}, 1]&.to_i) && step.positive? && [ day, month, weekday ].all?("*")
      return [ t(:every_hours_at, count: step, minute: minute.rjust(2, "0")), step.hours ]
    end
    hours = list(hour, 0..23) or return
    at = at_times(hours, minute)
    per_day = hours.size

    if [ day, month, weekday ].all?("*")
      [ t(:every_day, at: at), per_day == 1 ? 1.day : nil ]
    elsif month == "*" && day == "*"
      days, single = weekdays(weekday)
      return unless days

      [ t(:on_days, days: days, at: at), single && per_day == 1 ? 1.week : nil ]
    elsif month == "*" && weekday == "*"
      dates = list(day, 1..31) or return
      [ t(:on_dates, dates: dates.map { |date| day_of_month(date) }.to_sentence, at: at),
        dates.size == 1 && per_day == 1 ? 1.month : nil ]
    end
  end

  # "at 3:00 and 15:00" / "à 3 h 00 et 15 h 00".
  def at_times(hours, minute) = t(:at, times: hours.map { |hour| t(:time, hour: hour, minute: minute.rjust(2, "0")) }.to_sentence)

  def day_of_month(date) = date == 1 ? t(:first_of_month) : (I18n.locale.to_s.start_with?("en") ? date.ordinalize : date.to_s)

  # "1,3,5" / "1-5" / "7" → [1, 3, 5] (nil for anything else).
  def list(field, range)
    values = field.split(",").flat_map do |part|
      case part
      when /\A(\d+)\z/ then [ $1.to_i ]
      when /\A(\d+)-(\d+)\z/ then ($1.to_i..$2.to_i).to_a
      else return nil
      end
    end
    values.all? { |value| range.cover?(value) } ? values.uniq.sort : nil
  end

  # [text, single day?] of a weekday field ("1-5" → "from Monday to Friday").
  def weekdays(field)
    names = I18n.t("date.day_names")
    normalized = field.downcase.gsub(/[a-z]{3}/) { |name| DAY_NAMES.fetch(name) { return nil }.to_s }
    if (range = normalized.match(/\A(\d)-(\d)\z/))
      return [ t(:from_to, first: names[range[1].to_i % 7], last: names[range[2].to_i % 7]), false ]
    end
    days = list(normalized, 0..7) or return
    days = days.map { |day| day % 7 }.uniq.sort_by { |day| day.zero? ? 7 : day } # the week starts on Monday
    [ t(:on_day, day: days.map { |day| names[day] }.to_sentence), days.one? ]
  end

  # Common OnCalendar= forms: shorthands, "*-*-* 06:00:00", "Mon *-*-* 04:00", "*-*-01 02:00".
  def describe_calendar(value)
    return nickname_text(CALENDAR_NICKNAMES[value.downcase]) if CALENDAR_NICKNAMES.key?(value.downcase)

    match = value.match(/\A(?:(?<days>[A-Za-z,.]+)\s+)?(?:(?<date>[\d*]+-[\d*]+-[\d*]+)\s+)?(?<time>[\d*,\/]+:[\d*\/]+(?::[\d*\/]+)?)\z/)
    return [ quoted(value), nil ] unless match

    hour, minute = match[:time].split(":")
    _, month, day = (match[:date] || "*-*-*").split("-")
    weekday = match[:days] ? match[:days].downcase.gsub("..", "-") : "*"
    minute = minute.sub(/\A0(\d)\z/, '\1')
    hour = hour.gsub(/\b0(\d)\b/, '\1')
    day = day.sub(/\A0(\d)\z/, '\1')
    month = month.sub(/\A0(\d)\z/, '\1')
    describe_fields(minute == "*" ? "*" : minute, hour, day, month, weekday) || [ quoted(value), nil ]
  end

  def human_span(seconds)
    [ [ 86_400, :days ], [ 3600, :hours ], [ 60, :minutes ], [ 1, :seconds ] ].each do |size, unit|
      return t("span.#{unit}", count: seconds / size) if (seconds % size).zero? && seconds >= size
    end
    t("span.seconds", count: seconds)
  end
end
