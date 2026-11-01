class AddScoreBandsToAppSettings < ActiveRecord::Migration[8.1]
  def change
    # Colour of a CVSS score: from which score each colour applies (Settings → Vulnérabilités).
    add_column :app_settings, :score_bands, :jsonb, null: false,
               default: [ { "from" => 0, "color" => "green" }, { "from" => 4, "color" => "orange" }, { "from" => 7, "color" => "red" } ]
  end
end
