require_relative "boot"

require "rails/all"
require_relative "../lib/elio/secrets"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Elio
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Europe/Paris"
    config.i18n.default_locale = :fr
    config.i18n.available_locales = %i[fr en]
    # config.eager_load_paths << Rails.root.join("extras")

    # Database encryption keys from the environment (lib/elio/secrets.rb),
    # else Rails credentials. SECRET_KEY_BASE is read by Rails itself.
    Elio::Secrets.encryption_keys.each { |key, value| config.active_record.encryption.public_send(:"#{key}=", value) }
  end
end
