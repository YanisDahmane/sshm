require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "time_left_in_words in French" do
    freeze_time do
      assert_equal "moins d'une minute", time_left_in_words(30.seconds.from_now)
      assert_equal "moins d'une minute", time_left_in_words(1.minute.ago)
      assert_equal "1 minute", time_left_in_words(60.seconds.from_now)
      assert_equal "10 minutes", time_left_in_words(9.minutes.from_now + 30.seconds)
      assert_equal "1 heure", time_left_in_words(60.minutes.from_now)
      assert_equal "4 heures", time_left_in_words(4.hours.from_now)
      assert_equal "1 jour", time_left_in_words(1.day.from_now)
      assert_equal "7 jours", time_left_in_words(7.days.from_now)
    end
  end
end
