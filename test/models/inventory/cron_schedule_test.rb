require "test_helper"

class Inventory::CronScheduleTest < ActiveSupport::TestCase
  def cron(expression) = Inventory::CronSchedule.cron(expression)
  def timer(setting) = Inventory::CronSchedule.timer(setting)

  test "describes the common cron expressions in French, with their period" do
    {
      "* * * * *" => [ "toutes les minutes", 60 ],
      "*/5 * * * *" => [ "toutes les 5 minutes", 300 ],
      "17 * * * *" => [ "toutes les heures à :17", 3600 ],
      "0 */6 * * *" => [ "toutes les 6 heures à :00", 21_600 ],
      "25 6 * * *" => [ "tous les jours à 6 h 25", 86_400 ],
      "0 6,18 * * *" => [ "tous les jours à 6 h 00 et 18 h 00", nil ],
      "47 6 * * 7" => [ "le dimanche à 6 h 47", 604_800 ],
      "0 8 * * 1-5" => [ "du lundi au vendredi à 8 h 00", nil ],
      "0 8 * * mon,thu" => [ "le lundi et jeudi à 8 h 00", nil ],
      "52 6 1 * *" => [ "le 1er du mois à 6 h 52", 1.month.to_i ],
      "5-55/10 * * * *" => [ "toutes les 10 minutes à partir de :05", 600 ],
      "00 00 * * 6,0" => [ "le samedi et dimanche à 0 h 00", nil ],
      "@reboot" => [ "au démarrage", nil ],
      "@daily" => [ "tous les jours à 0 h 00", 86_400 ]
    }.each do |expression, (text, period)|
      schedule = cron(expression)
      assert_equal text, schedule.text, expression
      period ? assert_equal(period, schedule.period.to_i, expression) : assert_nil(schedule.period, expression)
    end
  end

  test "unusual expressions are quoted as they are" do
    assert_equal "« 0 3 1-7 * 1 »", cron("0 3 1-7 * 1").text
    assert_equal "« 5 4 * jan * »", cron("5 4 * jan *").text
    assert_equal "pas une expression", cron("pas une expression").text
  end

  test "describes systemd timers, normalized or not" do
    assert_equal [ "tous les jours à 6 h 00", 86_400 ], timer("OnCalendar=*-*-* 06:00:00").then { [ it.text, it.period.to_i ] }
    assert_equal "tous les jours à 0 h 00 et 12 h 00", timer("OnCalendar=*-*-* 00,12:00:00").text
    assert_equal "le lundi à 0 h 00", timer("OnCalendar=Mon *-*-* 00:00:00").text
    assert_equal "du lundi au vendredi à 7 h 30", timer("OnCalendar=Mon..Fri *-*-* 07:30:00").text
    assert_equal "le 1er du mois à 2 h 00", timer("OnCalendar=*-*-01 02:00:00").text
    assert_equal "tous les jours à 0 h 00", timer("OnCalendar=daily").text
    assert_equal [ "1 jour après le dernier lancement", 86_400 ], timer("OnUnitActiveUSec=1d").then { [ it.text, it.period ] }
    assert_equal [ "15 minutes après le démarrage", nil ], timer("OnBootUSec=15min").then { [ it.text, it.period ] }
    assert_equal "« *-*-* 04:00:00 Europe/Paris »", timer("OnCalendar=*-*-* 04:00:00 Europe/Paris").text
  end

  test "reads systemd time spans" do
    assert_equal 86_400, Inventory::CronSchedule.span("1d")
    assert_equal 5400, Inventory::CronSchedule.span("1h 30min")
    assert_equal 900, Inventory::CronSchedule.span("15min")
    assert_nil Inventory::CronSchedule.span("soon")
  end
end
