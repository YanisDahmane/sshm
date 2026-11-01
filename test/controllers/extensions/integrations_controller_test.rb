require "test_helper"

class IntegrationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include IntegrationHelpers

  def run(...)
    with_integrations { super }
  end

  setup { sign_in users(:one) }

  test "admins only" do
    sign_in users(:operator)
    get settings_integrations_path
    assert_response :forbidden
    patch settings_integration_path("demo"), params: { integration: { enabled: "1" } }
    assert_response :forbidden
  end

  test "lists the extensions in a settings tab" do
    get settings_integrations_path
    assert_select "nav.settings-nav a[aria-current=page]", "Extensions"
    assert_select "#integration-demo .integration-state", "Désactivée"
    assert_select "#integration-demo a[href=?]", edit_settings_integration_path("demo"), text: "Configurer et activer"
  end

  test "the form shows the fields by section, never the secret" do
    enable_demo
    get edit_settings_integration_path("demo")
    assert_equal %w[Connexion Ressources Alertes], css_select("fieldset.integration-section > legend").map(&:text)
    assert_select "input[name='integration[values][url]'][value='https://demo.example']"
    assert_select "input[type=password][name='integration[values][api_key]']:not([value])"
    assert_select "input[name='integration[values][api_key]'][placeholder*='laisser vide']"
    assert_select "input[type=checkbox][name='integration[values][products][]'][value=ip][checked]"
    assert_select "input[name='integration[values][threshold]'][value='14']"
    assert_not_includes response.body, "secret-key"
  end

  test "enabling saves, logs and starts a first synchronization" do
    assert_difference -> { BackgroundTask.count } do
      patch settings_integration_path("demo"), params: { integration: { enabled: "1", values: { url: "https://demo.example", api_key: "k", products: [ "", "dns" ] } } }
    end

    integration = Integration.find_by!(kind: "demo")
    assert integration.enabled?
    assert_equal [ "k", %w[dns] ], [ integration.value(:api_key), integration.value(:products) ]
    assert Activity.of_kind(:integration_enabled).exists?
    assert_redirected_to edit_settings_integration_path("demo")
    assert_match "première synchronisation lancée", flash[:notice]
  end

  test "cannot be enabled without its required fields" do
    patch settings_integration_path("demo"), params: { integration: { enabled: "1", values: { url: "" } } }
    assert_response :unprocessable_entity
    assert_select "#error_explanation", text: /URL : obligatoire/
    assert_not Integration.find_by(kind: "demo")&.enabled?
  end

  test "disabling is logged, a blank secret is kept" do
    enable_demo
    patch settings_integration_path("demo"), params: { integration: { enabled: "0", values: { url: "https://demo.example", api_key: "" } } }
    assert_not Integration.find_by!(kind: "demo").enabled?
    assert_equal "secret-key", Integration.find_by!(kind: "demo").value(:api_key)
    assert Activity.of_kind(:integration_disabled).exists?
  end

  test "testing the connection uses the form values without saving them" do
    enable_demo
    patch test_settings_integration_path("demo"), params: { integration: { values: { url: "https://bad.example" } } }, as: :turbo_stream
    assert_select "turbo-stream[target=integration-test-result] [data-result=crit]", text: /Échec : hôte injoignable/
    assert_equal "https://demo.example", Integration.find_by!(kind: "demo").value(:url)

    post test_settings_integration_path("demo"), params: { integration: { values: { url: "https://ok.example" } } }, as: :turbo_stream
    assert_select "[data-result=good]", text: /Connexion réussie : 3 éléments trouvés/
  end

  test "synchronize now" do
    post sync_settings_integration_path("demo")
    assert_redirected_to edit_settings_integration_path("demo")
    assert_match "Activez", flash[:alert]

    enable_demo
    post sync_settings_integration_path("demo")
    assert_redirected_to task_path(BackgroundTask.recent.first)
  end

  test "unknown extension" do
    get edit_settings_integration_path("nope")
    assert_response :not_found
  end

  test "an enabled extension adds its server tab and sidebar link, nothing when disabled" do
    get server_path(servers(:web), tab: "demo")
    assert_select "nav.server-tabs a[data-tab=demo]", 0
    assert_select "#demo-tab", 0
    assert_select "nav.main-nav a[data-integration-link]", 0

    enable_demo
    get server_path(servers(:web), tab: "demo")
    assert_select "nav.server-tabs a[data-tab=demo][aria-current=page]", text: /Démo\s*2/
    assert_select "#demo-tab", text: /Onglet de démonstration de Web/
    assert_select "nav.main-nav a[data-integration-link]", text: "Démo"
  end

  test "an extension's health reasons count in the server health" do
    enable_demo(alert: true)
    servers(:web).refresh_health!
    assert_equal "warn", servers(:web).reload.health_status
    assert_includes servers(:web).health_reason_texts, "Alerte de démonstration"
  end
end
