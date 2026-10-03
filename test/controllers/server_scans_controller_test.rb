require "test_helper"

class ServerScansControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  test "requires authentication" do
    post server_scans_path
    assert_redirected_to new_user_session_path
    assert_no_enqueued_jobs
  end

  test "enqueues a scan of every server" do
    sign_in users(:one)

    post server_scans_path, headers: { "HTTP_REFERER" => servers_url }

    assert_enqueued_jobs 3, only: ScanServerJob
    assert_redirected_to servers_url
    assert_equal "Scan des clés lancé sur 3 serveurs. Actualisez la page dans quelques instants.", flash[:notice]
  end
end
