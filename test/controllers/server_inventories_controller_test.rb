require "test_helper"

class ServerInventoriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  test "requires authentication" do
    post server_inventory_path(servers(:web))
    assert_redirected_to new_user_session_path
  end

  test "starts the inventory of one server in the background" do
    sign_in users(:operator)

    assert_enqueued_with(job: Inventory::CollectJob, args: [ servers(:web) ]) do
      post server_inventory_path(servers(:web))
    end

    assert_redirected_to server_path(servers(:web))
    assert_equal "Inventaire de « Web » lancé. Actualisez la page dans quelques instants.", flash[:notice]
  end

  test "starts the inventory of every server" do
    sign_in users(:one)

    assert_enqueued_jobs(3, only: Inventory::CollectJob) { post server_inventories_path }

    assert_redirected_to servers_path
    assert_equal "Inventaire lancé sur 3 serveurs. Actualisez la page dans quelques instants.", flash[:notice]
  end

  test "returns 404 for an unknown server" do
    sign_in users(:one)
    post server_inventory_path(server_id: 0)
    assert_response :not_found
  end

  test "the server page offers to refresh the inventory to operators only" do
    sign_in users(:operator)
    get server_path(servers(:web))
    assert_select "form.refresh-inventory[action=?] button", server_inventory_path(servers(:web)), text: /Actualiser l'inventaire/

    sign_in users(:viewer)
    get server_path(servers(:web))
    assert_select "form.refresh-inventory", 0
  end
end
