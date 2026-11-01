module Settings
  # Vulnerability feeds (admins): state of each feed, update now, import a
  # file by hand (closed networks), and from which severity a fixable CVE
  # raises an alert.
  class VulnerabilitiesController < ApplicationController
    require_permission :administer

    MAX_IMPORT = 1.gigabyte
    IMPORT_DIR = Rails.root.join("storage", "vulnerabilities")

    def show
      @feeds = Vulnerability::SOURCES.keys.map { |source| VulnerabilityFeed.for(source) }
      @releases = Vulnerabilities.releases
      @automation = Automation.all_kinds.find { |automation| automation.kind == "vulnerabilities_update" }
      @setting = AppSetting.current
    end

    def update
      setting = AppSetting.current
      if setting.update(params.expect(app_setting: [ :vulnerability_alert_severity ]))
        Server.find_each(&:refresh_health!)
        redirect_to settings_vulnerabilities_path, notice: "Alertes de vulnérabilités enregistrées."
      else
        redirect_to settings_vulnerabilities_path, alert: setting.errors.full_messages.to_sentence
      end
    end

    # Downloads the feeds now (the daily automation, run once).
    def refresh
      automation = Automation.all_kinds.find { |candidate| candidate.kind == "vulnerabilities_update" }
      task = automation.enqueue!(user: current_user, tracked: true)
      redirect_to task_path(task), notice: "Mise à jour des bases de vulnérabilités lancée."
    end

    # A Debian Security Tracker JSON or an Ubuntu OSV zip, recognized by its content.
    def import
      file = params[:file]
      return redirect_to(settings_vulnerabilities_path, alert: "Choisissez un fichier.") unless file.respond_to?(:path)
      return redirect_to(settings_vulnerabilities_path, alert: "Fichier trop volumineux.") if file.size > MAX_IMPORT

      source = Vulnerabilities::Update.detect(file.path)
      return redirect_to(settings_vulnerabilities_path, alert: "Fichier non reconnu : JSON du Debian Security Tracker ou archive OSV d'Ubuntu (.zip) attendu.") unless source

      FileUtils.mkdir_p(IMPORT_DIR)
      path = IMPORT_DIR.join("import-#{SecureRandom.hex(8)}")
      FileUtils.cp(file.path, path)
      label = "Import : #{Vulnerability::SOURCES.fetch(source)}"
      task = BackgroundTask.enqueue!(kind: "vulnerabilities", label: label, servers: [], user: current_user)
      ImportVulnerabilitiesJob.perform_later(source, path.to_s, task)
      redirect_to task_path(task), notice: "Import lancé (#{Vulnerability::SOURCES.fetch(source)})."
    end
  end
end
