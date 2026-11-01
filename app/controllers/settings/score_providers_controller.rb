module Settings
  # Score providers of the CVEs (admins): order, on / off, custom ones
  # (JSON API or HTML page), and a test on a CVE before trusting them.
  class ScoreProvidersController < ApplicationController
    require_permission :administer

    before_action :set_provider, only: %i[edit update destroy move toggle test]
    CVE = /\ACVE-\d{4}-\d{4,}\z/

    def new
      @provider = ScoreProvider.new(kind: "custom", settings: { "format" => "html" })
    end

    def create
      @provider = ScoreProvider.new(kind: "custom", key: "custom-#{SecureRandom.hex(4)}", position: ScoreProvider.all_providers.map(&:position).max.to_i + 1)
                               .assign_custom(provider_params)
      if @provider.save
        redirect_to settings_vulnerabilities_path(anchor: "score-providers"), notice: t("score_providers_controller.created", provider_name: @provider.name)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      head(:not_found) unless @provider.custom?
    end

    def update
      return head(:not_found) unless @provider.custom?

      if @provider.assign_custom(provider_params).save
        redirect_to settings_vulnerabilities_path(anchor: "score-providers"), notice: t("score_providers_controller.updated", provider_name: @provider.name)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      return head(:not_found) unless @provider.custom?

      @provider.scores.delete_all
      @provider.destroy!
      CveRating.refresh!
      redirect_to settings_vulnerabilities_path(anchor: "score-providers"), notice: t("score_providers_controller.deleted", provider_name: @provider.name), status: :see_other
    end

    # Up or down in the priority order (swaps with its neighbour).
    def move
      providers = ScoreProvider.all_providers
      index = providers.index(@provider)
      other = providers[params[:direction] == "up" ? index - 1 : index + 1] if index
      if other && (params[:direction] != "up" || index.positive?)
        providers[index], providers[providers.index(other)] = other, @provider
        ScoreProvider.transaction { providers.each_with_index { |provider, position| provider.update_columns(position: position) } }
      end
      redirect_to settings_vulnerabilities_path(anchor: "score-providers"), status: :see_other
    end

    def toggle
      @provider.update!(enabled: !@provider.enabled?)
      CveRating.refresh!
      redirect_to settings_vulnerabilities_path(anchor: "score-providers"), status: :see_other,
                  notice: t(@provider.enabled? ? "score_providers_controller.enabled" : "score_providers_controller.disabled", provider_name: @provider.name)
    end

    # Reads one CVE with a saved provider, without storing anything.
    def test = render_test(@provider)

    # Same with the values of the form (provider not saved yet).
    def preview
      provider = ScoreProvider.new(kind: "custom", key: "preview").assign_custom(provider_params)
      return render_result(provider, error: provider.errors.full_messages.to_sentence) unless provider.valid?

      render_test(provider)
    end

    private

    def set_provider = @provider = ScoreProvider.find(params[:id])

    def provider_params = params.expect(score_provider: %i[name url_template page_url_template format json_path css_selector regex delay_ms max_per_run])

    def render_test(provider)
      cve = params[:cve].to_s.strip.upcase
      return render_result(provider, error: t("score_providers_controller.cve_required")) unless cve.match?(CVE)

      render_result(provider, cve: cve, score: Vulnerabilities::Scores.fetcher(provider).test(cve))
    rescue Vulnerabilities::Error, Integrations::Error => e
      render_result(provider, cve: cve, error: e.message)
    end

    def render_result(provider, cve: nil, score: nil, error: nil)
      render turbo_stream: turbo_stream.update("score-provider-test-#{provider.persisted? ? provider.id : "new"}",
                                               partial: "settings/score_providers/test_result", locals: { provider: provider, cve: cve, score: score, error: error })
    end
  end
end
