# Display of the background tasks (see BackgroundTask).
module TasksHelper
  TASK_STATUSES = {
    "queued" => [ :neutral, "À venir", :clock ], "running" => [ :accent, "En cours", :arrow_path ],
    "succeeded" => [ :good, "Terminée", :check ], "partial" => [ :warn, "Terminée avec erreurs", :exclamation_triangle ],
    "failed" => [ :crit, "En échec", :x_mark ]
  }.freeze

  def task_status_badge(status, **options)
    tone, label, icon = TASK_STATUSES.fetch(status.to_s)
    status_badge(tone, label, icon: icon, data: { status: status }, **options)
  end

  # 72 s → "1 min 12 s", 4 s → "4 s".
  def task_duration(seconds)
    return "—" unless seconds

    seconds = seconds.round
    seconds < 60 ? "#{seconds} s" : "#{seconds / 60} min #{format("%02d", seconds % 60)} s"
  end

  def task_filter_count(filter)
    BackgroundTask::FILTERS.fetch(filter).sum { |status| @counts.fetch(status, 0) }
  end
end
