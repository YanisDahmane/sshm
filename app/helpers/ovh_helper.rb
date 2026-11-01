# Display of the OVHcloud resources (OvhResource).
module OvhHelper
  FIREWALL_VERDICTS = { permit: [ :warn, "OVH : autorisé" ], deny: [ :good, "OVH : bloqué" ], restricted: [ :good, "OVH : sources limitées" ] }.freeze

  def ovh_expiration(resource)
    return tag.span("—", class: "text-ink-3") unless resource.expires_at

    days = resource.days_left
    text = "#{l(resource.expires_at, format: :long)}#{" (renouvellement auto)" if resource.data["renew_automatic"]}"
    css = if days <= 7 then "text-crit-ink font-medium" elsif days <= 30 && !resource.data["renew_automatic"] then "text-warn-ink" else "text-ink-2" end
    tag.span(text, class: "ovh-expiration #{css}", title: "dans #{days} jour(s)")
  end

  def ovh_firewall_rule(rule)
    [ rule["sequence"], rule["action"] == "permit" ? "autoriser" : "refuser", rule["protocol"], rule["destinationPort"], (rule["source"] && "depuis #{rule["source"]}") ].compact_blank.join(" ")
  end

  def ovh_firewall_badge(verdict)
    return tag.span("OVH : pas de firewall", class: "text-xs text-ink-3") unless verdict

    tone, label = FIREWALL_VERDICTS.fetch(verdict)
    status_badge(tone, label, class: "ovh-firewall-verdict")
  end

  def ovh_match_label(resource) = OvhResource::MATCHES[resource.matched_by]
end
