# Imports a vulnerability feed uploaded from the settings (closed networks),
# followed by its BackgroundTask. The uploaded copy is removed afterwards.
class ImportVulnerabilitiesJob < ApplicationJob
  queue_as :default

  def perform(source, path, task = nil)
    task&.start!
    result = Vulnerabilities::Update.call(source, path: path)
    task&.refresh!(result: result)
  rescue Vulnerabilities::Error => e
    task&.fail!(e.message)
  ensure
    FileUtils.rm_f(path)
  end
end
