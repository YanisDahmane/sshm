# Setup steps shown on the dashboard until they are all done.
class OnboardingChecklist
  Step = Data.define(:key, :title, :description, :done) do
    def done? = done
  end

  def steps
    @steps ||= [
      Step.new(:ssh_key, I18n.t("onboarding_checklist.generate_key"), I18n.t("onboarding_checklist.generate_key_text"), SshKey.exists?),
      Step.new(:server, I18n.t("onboarding_checklist.add_server"), I18n.t("onboarding_checklist.add_server_text"), Server.exists?),
      Step.new(:install_key, I18n.t("onboarding_checklist.install_key"),
               I18n.t("onboarding_checklist.install_key_text"), Server.exists?(ssh_ok: true)),
      Step.new(:inventory, I18n.t("onboarding_checklist.inventory"), I18n.t("onboarding_checklist.inventory_text"),
               Server.where.not(inventoried_at: nil).exists?),
      Step.new(:public_key, I18n.t("onboarding_checklist.add_key"), I18n.t("onboarding_checklist.add_key_text"), PublicKey.exists?)
    ]
  end

  def done_count = steps.count(&:done?)

  def complete? = steps.all?(&:done?)

  # The first step still to do.
  def current = steps.find { |step| !step.done? }
end
