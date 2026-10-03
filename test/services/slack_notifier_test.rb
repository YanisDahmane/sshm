require "test_helper"

class SlackNotifierTest < ActiveSupport::TestCase
  include SlackHelpers
  include StubHelpers

  setup do
    @activity = Activity.record!(:unknown_key_detected, server: servers(:web), unix_user: "root", key_name: "bob@desktop")
  end

  test "builds a message with the severity, the label, the summary and the context" do
    payload = SlackNotifier.activity_payload(@activity)

    assert_equal ":warning: *Clé sans profil détectée*\nClé « bob@desktop » sans profil trouvée sur « Web » pour root", payload[:text]
    assert_equal "Par Système · Serveur : Web · Compte : root", payload[:blocks].last[:elements].first[:text]
  end

  test "mentions @channel when asked" do
    assert SlackNotifier.activity_payload(@activity, mention: true)[:text].start_with?("<!channel> :warning:")
    assert_not_includes SlackNotifier.activity_payload(@activity)[:text], "<!channel>"
  end

  test "escapes text coming from servers so it cannot mention or link" do
    activity = Activity.record!(:unknown_key_detected, server: servers(:web), unix_user: "root", key_name: "<!channel> <https://evil|click> & co")

    text = SlackNotifier.activity_payload(activity)[:text]

    assert_includes text, "&lt;!channel&gt; &lt;https://evil|click&gt; &amp; co"
    assert_not_includes text, "<!channel>"
  end

  test "deliver posts the payload to the channel's webhook" do
    channel = create_channel(mention_channel: true)
    posts = []

    stub_method(SlackNotifier, :post, ->(url, payload) { posts << [ url, payload ] }) { SlackNotifier.deliver(channel, @activity) }

    assert_equal WEBHOOK, posts.sole.first
    assert posts.sole.last[:text].start_with?("<!channel>")
  end

  test "deliver_test sends a short confirmation" do
    channel = create_channel(name: "#ops <b>")
    posts = []

    stub_method(SlackNotifier, :post, ->(url, payload) { posts << payload }) { SlackNotifier.deliver_test(channel) }

    assert_equal ":white_check_mark: Test SSHM : le canal « #ops &lt;b&gt; » reçoit bien les notifications.", posts.sole[:text]
  end

  test "post succeeds on a 2xx response" do
    ok = Net::HTTPOK.new("1.1", "200", "OK")

    response = stub_method(Net::HTTP, :start, ok) { SlackNotifier.post(WEBHOOK, { text: "hi" }) }

    assert_equal ok, response
  end

  test "post raises DeliveryError on an error response" do
    not_found = Net::HTTPNotFound.new("1.1", "404", "Not Found")
    not_found.instance_variable_set(:@body, "no_service")
    not_found.instance_variable_set(:@read, true)

    error = assert_raises(SlackNotifier::DeliveryError) do
      stub_method(Net::HTTP, :start, not_found) { SlackNotifier.post(WEBHOOK, { text: "hi" }) }
    end
    assert_equal "Slack a répondu 404 : no_service", error.message
  end

  test "post raises DeliveryError when Slack cannot be reached" do
    error = assert_raises(SlackNotifier::DeliveryError) do
      stub_method(Net::HTTP, :start, ->(*, **) { raise SocketError, "getaddrinfo failed" }) { SlackNotifier.post(WEBHOOK, { text: "hi" }) }
    end
    assert_match "Impossible de joindre Slack", error.message
  end
end
