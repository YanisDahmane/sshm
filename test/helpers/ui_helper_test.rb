require "test_helper"

class UiHelperTest < ActionView::TestCase
  include IconsHelper

  test "status_badge always pairs the colour with an icon and a label" do
    render html: status_badge(:crit, "Critique")

    assert_select "span.badge.bg-crit-soft.text-crit-ink", text: "Critique" do
      assert_select "svg", 1
    end
  end

  test "status_badge without icon" do
    render html: status_badge(:neutral, "Inconnu", class: "extra")

    assert_select "span.badge.extra", text: "Inconnu"
    assert_select "svg", 0
  end

  test "meter colours the fill by threshold and shows the value" do
    render html: meter(50) + meter(85) + meter(94.4, label: "Disque")

    assert_select ".meter", 3
    assert_select ".meter[data-tone=neutral] [role=meter][aria-valuenow='50'] .bg-ink-2[style='width: 50.0%']"
    assert_select ".meter[data-tone=warn] .bg-warn"
    assert_select ".meter[data-tone=crit]" do
      assert_select "span", text: "Disque"
      assert_select "span.text-crit-ink", text: "94 %"
    end
  end

  test "meter clamps out-of-range values and shows a dash without value" do
    render html: meter(150, value: false) + meter(nil)

    assert_select "[role=meter][aria-valuenow='100']"
    assert_select ".meter span", 0
    assert_select "span.text-ink-3", text: "—"
  end

  test "sparkline draws the values and marks the last point" do
    render html: sparkline([ 0, 50, 100 ], width: 24, height: 12, max: 100, title: "CPU 24 h")

    assert_select "svg.sparkline[role=img][aria-label='CPU 24 h']" do
      assert_select "title", "CPU 24 h"
      assert_select "path[d='M2.0,10.0 L12.0,6.0 L22.0,2.0']"
      assert_select "circle[cx='22.0'][cy='2.0']"
    end
  end

  test "sparkline needs at least two values" do
    render html: sparkline([ 3 ])
    assert_select "svg", 0
    assert_select "span", text: "—"
  end

  test "stat_tile shows a toned figure with its label and caption" do
    render html: stat_tile("Critiques", 3, "dont 1 injoignable", tone: :crit, icon: :x_mark, id: "stat-crit")

    assert_select ".stat-tile#stat-crit" do
      assert_select "p", text: "Critiques"
      assert_select ".stat-value.text-crit-ink", "3"
      assert_select "p", text: "dont 1 injoignable"
    end
  end

  test "sidebar_link marks the active page" do
    render html: sidebar_link("Parc", "/servers", icon: :server_stack, active: true, count: 12) +
                 sidebar_link("Trousseau", "/keys", icon: :key, active: false)

    assert_select "a[href='/servers'][aria-current=page].bg-accent-soft", text: /Parc\s*12/
    assert_select "a[href='/keys']:not([aria-current])", text: "Trousseau"
  end

  test "sidebar_server_groups counts the servers of each group" do
    counts = sidebar_server_groups.to_h { |group| [ group.name, group.servers_count ] }

    assert_equal ServerGroup.order(:name).pluck(:name), counts.keys
    assert_equal servers(:web).server_groups.first.servers.count, counts[servers(:web).server_groups.first.name]
  end
end
