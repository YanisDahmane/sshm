# Setup steps shown on the dashboard until they are all done.
class OnboardingChecklist
  Step = Data.define(:key, :title, :description, :done) do
    def done? = done
  end

  def steps
    @steps ||= [
      Step.new(:ssh_key, "Générer la clé SSH d'Elio", "Elio se connecte à vos serveurs avec sa propre clé.", SshKey.exists?),
      Step.new(:server, "Ajouter un serveur", "Son adresse, son port et l'utilisateur SSH.", Server.exists?),
      Step.new(:install_key, "Installer la clé et tester la connexion",
               "Ajoutez la clé publique d'Elio sur le serveur, puis lancez « Tester la connexion SSH ».", Server.exists?(ssh_ok: true)),
      Step.new(:inventory, "Lancer un premier inventaire", "Elio relève le système, la santé, les paquets, les services et les ports du serveur.",
               Server.where.not(inventoried_at: nil).exists?),
      Step.new(:public_key, "Ajouter une clé au trousseau", "La clé publique d'un membre de l'équipe ou d'un serveur.", PublicKey.exists?)
    ]
  end

  def done_count = steps.count(&:done?)

  def complete? = steps.all?(&:done?)

  # The first step still to do.
  def current = steps.find { |step| !step.done? }

end
