# End of security support of the Debian and Ubuntu releases (Debian: end of
# LTS; Ubuntu: end of standard support, without Ubuntu Pro). Update the table
# when new releases come out.
module Inventory::EndOfLife
  DATES = {
    "debian" => {
      "9" => "2022-06-30", "10" => "2024-06-30", "11" => "2026-08-31", "12" => "2028-06-30", "13" => "2030-06-30"
    },
    "ubuntu" => {
      "18.04" => "2023-05-31", "20.04" => "2025-05-31", "22.04" => "2027-06-01", "23.10" => "2024-07-11",
      "24.04" => "2029-05-31", "24.10" => "2025-07-10", "25.04" => "2026-01-15", "25.10" => "2026-07-15", "26.04" => "2031-05-31"
    }
  }.transform_values { |dates| dates.transform_values { |date| Date.iso8601(date) } }.freeze

  # Months before the end from which it is announced as coming soon.
  SOON = 6.months

  Status = Data.define(:state, :date) do
    def ended? = state == :ended
    def soon? = state == :soon
    def known? = state != :unknown
  end

  # :supported, :soon (within SOON), :ended or :unknown, with the date.
  def self.status(os_id, version_id, today: Date.current)
    date = date_for(os_id, version_id)
    state = if date.nil? then :unknown
    elsif date < today then :ended
    elsif date <= today + SOON then :soon
    else :supported
    end
    Status.new(state: state, date: date)
  end

  # Debian point releases ("12.7") share the major version's date.
  def self.date_for(os_id, version_id)
    dates = DATES[os_id.to_s]
    return unless dates && version_id.present?

    dates[version_id.to_s] || dates[version_id.to_s.split(".").first]
  end
end
