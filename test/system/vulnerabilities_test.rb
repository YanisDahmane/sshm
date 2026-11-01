require "application_system_test_case"

class VulnerabilitiesSystemTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include ScoreHelpers

  setup do
    vulnerable(servers(:web), "CVE-2024-6387")
    vulnerable(servers(:web), "CVE-2024-0002", severity: "low", fixed: nil)
    CveScore.store("nvd", [ { cve: "CVE-2024-6387", score: 8.1, version: "3.1", vector: "CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:U/C:H/I:H/A:H", data: { "description" => "regreSSHion" } } ])
    CveScore.store("kev", [ { cve: "CVE-2024-6387", score: 1, data: { "date_added" => "2024-07-03" } } ])
    CveRating.refresh!
    sign_in users(:viewer)
  end

  test "a click on a CVE of the server opens its detail in a modal, closed with Escape" do
    visit server_path(servers(:web), tab: "vulnerabilities")

    within("tr.server-vulnerability[data-cve='CVE-2024-6387']") do
      assert_selector ".cve-score", text: "8,1"
      assert_selector ".cve-exploited", text: "exploitée"
    end
    find("tr.server-vulnerability[data-cve='CVE-2024-6387']").click # the CVE link covers the whole row

    within("dialog.vulnerability-dialog[open]") do
      assert_selector ".vulnerability-detail[data-cve='CVE-2024-6387']"
      assert_text "regreSSHion"
      assert_text "Vecteur : réseau"
      assert_selector ".detail-on-server", text: /sur web/i # uppercase heading
    end
    find("body").send_keys(:escape)
    assert_no_selector "dialog.vulnerability-dialog[open]"

    find("a.vulnerability-link", text: "CVE-2024-0002").click
    assert_selector "dialog.vulnerability-dialog[open] .vulnerability-detail[data-cve='CVE-2024-0002']"
    assert_text "Aucun fournisseur n'a encore noté cette CVE."
  end
end
