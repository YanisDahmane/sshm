require "test_helper"

# AUDIT.md R1-R3: models, controllers and jobs live in their domain folder
# (config/initializers/autoloading.rb); only the base classes stay at the root.
class CodeLayoutTest < ActiveSupport::TestCase
  ROOT_FILES = {
    "app/models" => %w[application_record.rb inventory.rb],
    "app/controllers" => %w[application_controller.rb],
    "app/jobs" => %w[application_job.rb]
  }.freeze

  test "no file outside of a domain folder" do
    ROOT_FILES.each do |root, allowed|
      files = Dir[Rails.root.join(root, "*.rb")].map { |path| File.basename(path) }
      assert_equal allowed.sort, files.sort, "#{root}: put new files in a domain folder (#{DOMAIN_FOLDERS.fetch(root).join(", ")}) or a namespace"
    end
  end

  test "every domain folder exists and is not a namespace" do
    DOMAIN_FOLDERS.each do |root, folders|
      folders.each do |folder|
        assert Rails.root.join(root, folder).directory?, "#{root}/#{folder}"
        assert_not Object.const_defined?(folder.camelize), "#{folder.camelize} must not be a namespace"
      end
    end
    assert_equal "app/models/fleet/server.rb", Object.const_source_location("Server").first.delete_prefix("#{Rails.root}/")
  end
end
