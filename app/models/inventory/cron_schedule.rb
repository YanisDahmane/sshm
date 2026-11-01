# A cron schedule ("*/5 * * * *", "@daily", systemd "OnCalendar=…" or
# "OnUnitActiveSec=1d") described in French ("toutes les 5 minutes",
# "tous les jours à 3 h 00"), with its period in seconds when it is regular
# (used to tell a late timer). Unusual expressions are shown as they are.
class Inventory::CronSchedule
  NICKNAMES = { "@reboot" => [ "au démarrage", nil ], "@hourly" => [ "toutes les heures", 1.hour ], "@daily" => [ "tous les jours à 0 h 00", 1.day ],
                "@midnight" => [ "tous les jours à 0 h 00", 1.day ], "@weekly" => [ "le dimanche à 0 h 00", 1.week ],
                "@monthly" => [ "le 1er du mois à 0 h 00", 1.month ], "@yearly" => [ "le 1er janvier à 0 h 00", 1.year ],
                "@annually" => [ "le 1er janvier à 0 h 00", 1.year ] }.freeze
  DAYS = %w[dimanche lundi mardi mercredi jeudi vendredi samedi].freeze
  DAY_NAMES = { "sun" => 0, "mon" => 1, "tue" => 2, "wed" => 3, "thu" => 4, "fri" => 5, "sat" => 6 }.freeze
  # systemd shorthands of OnCalendar=.
  CALENDAR_NICKNAMES = { "minutely" => [ "toutes les minutes", 1.minute ], "hourly" => [ "toutes les heures", 1.hour ],
                         "daily" => [ "tous les jours à 0 h 00", 1.day ], "weekly" => [ "le lundi à 0 h 00", 1.week ],
                         "monthly" => [ "le 1er du mois à 0 h 00", 1.month ], "yearly" => [ "le 1er janvier à 0 h 00", 1.year ],
                         "annually" => [ "le 1er janvier à 0 h 00", 1.year ], "quarterly" => [ "tous les trimestres", 3.months ],
                         "semiannually" => [ "tous les six mois", 6.months ] }.freeze
  MONOTONIC = { "OnBootSec" => "après le démarrage", "OnStartupSec" => "après le démarrage", "OnActiveSec" => "après l'activation",
                "OnUnitActiveSec" => "après le dernier lancement", "OnUnitInactiveSec" => "après la fin du dernier lancement" }.freeze
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
      @text, @period = nickname
      return
    end

    minute, hour, day, month, weekday = @expression.split
    return unless weekday

    @text, @period = describe_fields(minute, hour, day, month, weekday) || [ "« #{@expression} »", nil ]
  end

  def describe_timer
    key, value = @expression.split("=", 2)
    return unless value

    key = key.sub(/USec\z/, "Sec") # `systemctl show` writes OnUnitActiveUSec=1d

    if key == "OnCalendar"
      @text, @period = describe_calendar(value.strip)
    elsif MONOTONIC.key?(key) && (seconds = self.class.span(value))
      @text = "#{human_span(seconds)} #{MONOTONIC[key]}"
      @period = seconds if key.in?(%w[OnUnitActiveSec OnUnitInactiveSec])
    end
  end

  def to_s = text

  private

  def describe_fields(minute, hour, day, month, weekday)
    return [ "toutes les minutes", 1.minute ] if [ minute, hour, day, month, weekday ].all?("*")
    return unless [ day, month ].all?("*") || weekday == "*"

    if hour == "*" && [ day, month, weekday ].all?("*")
      step = minute[%r{\A\*/(\d+)\z}, 1]&.to_i
      return [ step == 1 ? "toutes les minutes" : "toutes les #{step} minutes", step.minutes ] if step&.positive?
      if (offset = minute.match(%r{\A(\d+)(?:-\d+)?/(\d+)\z})) && offset[2].to_i.positive?
        return [ "toutes les #{offset[2]} minutes à partir de :#{offset[1].rjust(2, "0")}", offset[2].to_i.minutes ]
      end
      return [ "toutes les heures à :#{minute.rjust(2, "0")}", 1.hour ] if minute.match?(/\A\d+\z/)

      return
    end
    return unless minute.match?(/\A\d+\z/)

    if (step = hour[%r{\A\*/(\d+)\z}, 1]&.to_i) && step.positive? && [ day, month, weekday ].all?("*")
      return [ "toutes les #{step} heures à :#{minute.rjust(2, "0")}", step.hours ]
    end
    hours = list(hour, 0..23) or return
    at = "à #{hours.map { |h| "#{h} h #{minute.rjust(2, "0")}" }.to_sentence(words_connector: ", ", last_word_connector: " et ", two_words_connector: " et ")}"
    per_day = hours.size

    if [ day, month, weekday ].all?("*")
      [ "tous les jours #{at}", per_day == 1 ? 1.day : nil ]
    elsif month == "*" && day == "*"
      days = weekdays(weekday) or return
      [ "#{days} #{at}", days.start_with?("le ") && !days.include?(" et ") && per_day == 1 ? 1.week : nil ]
    elsif month == "*" && weekday == "*"
      dates = list(day, 1..31) or return
      [ "le #{dates.map { |date| date == 1 ? "1er" : date.to_s }.to_sentence(words_connector: ", ", last_word_connector: " et ", two_words_connector: " et ")} du mois #{at}",
        dates.size == 1 && per_day == 1 ? 1.month : nil ]
    end
  end

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

  def weekdays(field)
    normalized = field.downcase.gsub(/[a-z]{3}/) { |name| DAY_NAMES.fetch(name) { return nil }.to_s }
    if (range = normalized.match(/\A(\d)-(\d)\z/))
      first, last = range[1].to_i % 7, range[2].to_i % 7
      return "du #{DAYS[first]} au #{DAYS[last]}"
    end
    days = list(normalized, 0..7) or return
    names = days.map { |day| day % 7 }.uniq.sort_by { |day| day.zero? ? 7 : day }.map { |day| DAYS[day] } # the week starts on Monday
    names.one? ? "le #{names.first}" : "le #{names.to_sentence(words_connector: ", ", last_word_connector: " et ", two_words_connector: " et ")}"
  end

  # Common OnCalendar= forms: shorthands, "*-*-* 06:00:00", "Mon *-*-* 04:00", "*-*-01 02:00".
  def describe_calendar(value)
    return CALENDAR_NICKNAMES[value.downcase] if CALENDAR_NICKNAMES.key?(value.downcase)

    match = value.match(/\A(?:(?<days>[A-Za-z,.]+)\s+)?(?:(?<date>[\d*]+-[\d*]+-[\d*]+)\s+)?(?<time>[\d*,\/]+:[\d*\/]+(?::[\d*\/]+)?)\z/)
    return [ "« #{value} »", nil ] unless match

    hour, minute = match[:time].split(":")
    _, month, day = (match[:date] || "*-*-*").split("-")
    weekday = match[:days] ? match[:days].downcase.gsub("..", "-") : "*"
    minute = minute.sub(/\A0(\d)\z/, '\1')
    hour = hour.gsub(/\b0(\d)\b/, '\1')
    day = day.sub(/\A0(\d)\z/, '\1')
    month = month.sub(/\A0(\d)\z/, '\1')
    describe_fields(minute == "*" ? "*" : minute, hour, day, month, weekday) || [ "« #{value} »", nil ]
  end

  def human_span(seconds)
    [ [ 86_400, "jour", "jours" ], [ 3600, "heure", "heures" ], [ 60, "minute", "minutes" ], [ 1, "seconde", "secondes" ] ].each do |size, one, many|
      next unless (seconds % size).zero? && seconds >= size

      count = seconds / size
      return count == 1 ? "1 #{one}" : "#{count} #{many}"
    end
    "#{seconds} secondes"
  end
end
