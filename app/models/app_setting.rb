# Application-wide settings (a single row).
class AppSetting < ApplicationRecord
  def self.current = first || create!
end
