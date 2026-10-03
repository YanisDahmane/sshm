module ApplicationHelper
  # French "time left" until `time`, e.g. "9 minutes", "2 heures", "3 jours".
  def time_left_in_words(time)
    seconds = (time - Time.current).to_i
    return "moins d'une minute" if seconds < 60

    minutes = (seconds / 60.0).ceil
    return pluralize(minutes, "minute") if minutes < 60

    hours = (minutes / 60.0).round
    return pluralize(hours, "heure") if hours < 24

    pluralize((hours / 24.0).round, "jour")
  end
end
