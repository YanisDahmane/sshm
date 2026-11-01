# Content Security Policy (AUDIT.md S1): scripts only from Elio itself, with
# a per-request nonce for the importmap and the theme script; no plugins, no
# framing, forms only towards Elio. `style=` attributes stay allowed (gauge
# widths, set by the server), <style> elements need the nonce (Turbo's
# progress bar reads it from csp_meta_tag).
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self
    policy.style_src :self
    policy.style_src_attr :unsafe_inline
    policy.img_src :self, :data
    policy.font_src :self, :data
    policy.connect_src :self
    policy.object_src :none
    policy.base_uri :self
    policy.form_action :self
    policy.frame_ancestors :none
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
