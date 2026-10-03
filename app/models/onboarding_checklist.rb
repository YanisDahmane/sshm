# Setup steps shown on the dashboard until they are all done.
class OnboardingChecklist
  Step = Data.define(:key, :title, :description, :done) do
    def done? = done
  end

  def steps
    @steps ||= [
      Step.new(:ssh_key, "Générer la clé SSH de SSHM", "SSHM se connecte à vos serveurs avec sa propre clé.", SshKey.exists?),
      Step.new(:server, "Ajouter un serveur", "Son adresse, son port et l'utilisateur SSH.", Server.exists?),
      Step.new(:install_key, "Installer la clé et tester la connexion",
               "Ajoutez la clé publique de SSHM sur le serveur, puis lancez « Tester la connexion SSH ».", Server.exists?(ssh_ok: true)),
      Step.new(:profile, "Créer un profil", "Une personne ou une machine, avec sa clé publique.", Profile.exists?),
      Step.new(:authorize, "Autoriser un profil sur un serveur", "Depuis la page d'un serveur, section « Clés autorisées ».", profile_authorized?)
    ]
  end

  def done_count = steps.count(&:done?)

  def complete? = steps.all?(&:done?)

  # The first step still to do.
  def current = steps.find { |step| !step.done? }

  private

  def profile_authorized?
    fingerprints = Profile.pluck(:fingerprint).to_set
    fingerprints.any? && AccountSnapshot.find_each.any? { |snapshot| snapshot.fingerprints.any? { |fingerprint| fingerprints.include?(fingerprint) } }
  end
end
