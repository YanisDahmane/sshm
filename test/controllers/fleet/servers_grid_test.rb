require "test_helper"

# Grid view of the fleet (cards, like the "B" mockup), next to the list.
class ServersGridTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionView::RecordIdentifier

  setup do
    sign_in users(:viewer)
    servers(:db).update_columns(reachable: true, health_status: "crit", health_reasons: [ { "tone" => "crit", "text" => "Disque / à 94 %" } ])
    servers(:web).update_columns(health_status: "ok")
    servers(:backup).update_columns(reachable: false)
    servers(:web).inventory_snapshots.create!(category: "health", status: "ok", collected_at: Time.current, checked_at: Time.current,
                                               data: { "load_percent" => 10, "memory" => { "used_percent" => 61 }, "disk_max_percent" => 48, "updates" => { "total" => 3, "security" => 0 } })
  end

  test "the list stays the default view" do
    get servers_path
    assert_select "#servers"
    assert_select "#servers-grid", 0
    assert_select ".view-toggle a[data-view=list][aria-pressed=true]"
  end

  test "cards, the problems first, and the choice is remembered" do
    get servers_path(view: "grid")

    assert_select "#servers", 0
    assert_equal %w[Backup Database Web], css_select("#servers-grid .server-card a.font-semibold").map(&:text), "unreachable and critical first, then by name"
    assert_select ".view-toggle a[data-view=grid][aria-pressed=true]"

    assert_select "##{dom_id(servers(:db), :card)}[data-state=crit] .server-card-footer", text: /Disque \/ à 94 %/
    assert_includes css_select("##{dom_id(servers(:db), :card)}").first["class"], "border-crit/40"
    assert_select "##{dom_id(servers(:backup), :card)}[data-state=off]", text: /Pas de réponse/
    assert_select "##{dom_id(servers(:web), :card)} .server-card-gauges .meter", 3
    assert_select "##{dom_id(servers(:web), :card)} .server-card-gauges", text: /CPU.*RAM.*61 %.*Disque.*48 %/m
    assert_select "##{dom_id(servers(:web), :card)} .server-card-footer", text: /3 mises à jour/

    get servers_path
    assert_select "#servers-grid" # (remembered in a cookie)
    get servers_path(view: "list")
    assert_select "#servers"
  end

  test "the filters keep working in the grid, and the toggle keeps them" do
    get servers_path(view: "grid", state: "crit")
    assert_select ".server-card", 1
    assert_select ".view-toggle a[data-view=list][href=?]", servers_path(state: "crit", view: "list")
  end
end
