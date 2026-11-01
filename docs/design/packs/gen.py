# Generates the 5 interface packs (A to E) of Elio as static mockups:
# every main page in each pack, light (+ dark for the key pages, mobile for
# the fleet and the server page), and a gallery to compare them page by page.
#
#   python3 docs/design/packs/gen.py   (then build.sh compiles the CSS and takes the screenshots)
#
# Same fictional data everywhere (TEST-NET / private addresses); each pack
# has its own tokens (pack.css), typography, shapes and page layouts.
import os, random

OUT = os.path.dirname(os.path.abspath(__file__))
random.seed(11)

# ============================================================== data
#  name, host, group, os, state, cpu, ram, disk, updates, sec, ports, reason, vulns
FLEET = [
    ("db-prod", "10.0.1.20", "Production", "Debian 12", "crit", 48, 88, 94, 12, 4, "22, 5432", "Disque / à 94 %", 3),
    ("ci-runner", "10.0.3.9", "Staging", "Ubuntu 22.04", "down", None, None, None, None, 0, "—", "Injoignable depuis 12 min", 0),
    ("legacy-ftp", "198.51.100.77", "Infra", "Debian 10", "crit", 22, 54, 71, 87, 31, "21, 22, 3306", "MySQL exposé publiquement", 14),
    ("worker-1", "10.0.1.30", "Production", "Ubuntu 22.04", "warn", 78, 72, 66, 18, 6, "22", "Redémarrage requis", 2),
    ("backup", "10.0.2.5", "Infra", "Debian 11", "warn", 5, 31, 81, 41, 9, "22, 873", "Debian 11 : fin de support", 5),
    ("web-prod-1", "203.0.113.4", "Production", "Ubuntu 24.04", "ok", 10, 61, 48, 3, 0, "22, 80, 443", None, 0),
    ("web-prod-2", "203.0.113.5", "Production", "Ubuntu 24.04", "ok", 9, 58, 51, 3, 0, "22, 80, 443", None, 0),
    ("cache-prod", "10.0.1.21", "Production", "Debian 12", "ok", 3, 44, 23, 0, 0, "22", None, 0),
    ("worker-2", "10.0.1.31", "Production", "Ubuntu 22.04", "ok", 20, 69, 64, 18, 6, "22", None, 2),
    ("monitoring", "10.0.2.8", "Infra", "Debian 12", "ok", 14, 63, 39, 2, 0, "22, 3000, 9090", None, 0),
    ("vpn", "203.0.113.11", "Infra", "Ubuntu 24.04", "ok", 1, 22, 18, 0, 0, "22, 51820/udp", None, 0),
    ("staging", "10.0.3.2", "Staging", "Ubuntu 24.04", "ok", 8, 47, 57, 5, 1, "22, 80, 443, 8080", None, 1),
]
LABEL = {"ok": "En ligne", "warn": "À surveiller", "crit": "Critique", "down": "Injoignable"}
TONE = {"ok": "good", "warn": "warn", "crit": "crit", "down": "crit"}
ICON_OF = {"ok": "check", "warn": "alert", "crit": "x", "down": "off"}
COUNTS = {k: sum(1 for s in FLEET if s[4] == k) for k in LABEL}

ATTENTION = [
    ("crit", "db-prod", "Disque / à 94 % — plein dans ≈ 4 jours", "Voir"),
    ("crit", "legacy-ftp", "MySQL (3306) exposé publiquement, firewall inactif", "Ports"),
    ("crit", "ci-runner", "Injoignable depuis 12 min", "Vérifier"),
    ("warn", "worker-1", "Redémarrage requis (noyau mis à jour)", "Voir"),
    ("warn", "backup", "Debian 11 : fin de support le 30 juin 2026", "Voir"),
    ("warn", "7 serveurs", "57 mises à jour de sécurité disponibles", "Paquets"),
]
SERVER_ATTENTION = [
    ("crit", "Disque /", "94 % — plein dans ≈ 4 jours au rythme actuel", "Disques"),
    ("crit", "3 vulnérabilités", "CVE-2026-3187 (openssl), CVE-2026-2210 (curl)… corrigeables", "Voir"),
    ("warn", "Mémoire", "88 % (seuil 80 %)", "Santé"),
    ("warn", "4 mises à jour de sécurité", "openssl, curl, postgresql-15, libc6", "Paquets"),
    ("warn", "Port 6432/tcp", "publié par Docker (pgbouncer) : ufw ne le filtre pas", "Ports"),
]
ACTIVITY = [
    ("14:02", "crit", "db-prod", "Disque / au-dessus de 90 %", "Système"),
    ("13:40", "info", "worker-1", "linux-image-6.1.0-28 mis à jour", "Système"),
    ("11:15", "warn", "staging", "Port 8080/tcp ouvert publiquement (node)", "Système"),
    ("10:58", "info", "db-prod", "Clé « Bastien Roy » ajoutée pour 24 h", "alice@acme.fr"),
    ("09:30", "crit", "ci-runner", "Ne répond plus", "Système"),
    ("09:12", "info", "web-prod-1", "Inventaire terminé (6 catégories)", "Système"),
    ("08:00", "info", "—", "Résumé quotidien envoyé sur #ops", "Système"),
]
PACKAGES = [
    ("openssl", "3.0.14-1~deb12u1", "3.0.15-1~deb12u1", True, 7),
    ("linux-image-amd64", "6.1.0-25", "6.1.0-28", True, 5),
    ("curl", "7.88.1-10+deb12u7", "7.88.1-10+deb12u8", True, 6),
    ("nginx", "1.22.1-9", None, False, 4),
    ("postgresql-15", "15.8-0+deb12u1", "15.10-0+deb12u1", True, 1),
    ("docker-ce", "27.3.1", "27.4.0", False, 6),
]
PORTS = [
    ("3306/tcp", "legacy-ftp", "mysqld", "mysql.service", "open", True),
    ("21/tcp", "legacy-ftp", "vsftpd", "vsftpd.service", "open", True),
    ("8080/tcp", "staging", "node", "conteneur api", "docker", True),
    ("6432/tcp", "db-prod", "docker-proxy", "conteneur pgbouncer", "docker", False),
    ("443/tcp", "web-prod-1", "nginx", "nginx.service", "allowed", False),
    ("80/tcp", "web-prod-1", "nginx", "nginx.service", "allowed", False),
    ("22/tcp", "vpn", "sshd", "ssh.service", "allowed", False),
    ("51820/udp", "vpn", "—", "wg-quick@wg0", "allowed", False),
]
MONITORS = [
    ("[SRV] [INTRANET] db-prod", "db-prod", "ping", "10.8.0.20", "wg0 (WireGuard)", "up", 0.4, 99.98),
    ("API publique", "web-prod-1", "http", "https://api.acme.fr", "203.0.113.4", "up", 84, 99.95),
    ("[SRV] legacy-ftp", "legacy-ftp", "ping", "198.51.100.77", "", "up", 12, 99.1),
    ("[SRV] ci-runner", "ci-runner", "ping", "10.8.0.39", "wg0 (WireGuard)", "down", None, 97.2),
    ("Site vitrine", None, "http", "https://www.acme.fr", "", "up", 120, 99.99),
]
KEYS = [
    ("Alice Martin", "Personne", "ed25519", "9 serveurs", "SHA256:q2Rk…7Hc"),
    ("Bastien Roy", "Personne", "ed25519", "1 serveur · expire dans 22 h", "SHA256:Lm9f…2xA"),
    ("Chloé Petit", "Personne", "rsa 4096", "4 serveurs", "SHA256:Zp1a…k9Q"),
    ("GitHub Actions", "Serveur", "ed25519", "6 serveurs", "SHA256:Ar5t…Wq0"),
    ("Sauvegarde restic", "Serveur", "ed25519", "11 serveurs", "SHA256:Vv8n…cE3"),
]
TASKS = [
    ("Inventaire du parc (12 serveurs)", "running", "8/12", "alice@acme.fr", "il y a 1 min", "—"),
    ("Synchronisation Uptime Kuma", "succeeded", "—", "Système", "il y a 6 min", "1 s"),
    ("Scan des clés (12 serveurs)", "partial", "12/12 · 1 erreur", "Système", "il y a 2 h", "14 s"),
    ("Inventaire de « db-prod »", "succeeded", "1/1", "bastien@acme.fr", "il y a 3 h", "4 s"),
    ("Synchronisation OVHcloud", "failed", "—", "Système", "il y a 6 h", "2 s"),
]
TASK_STATES = {"queued": ("neutral", "À venir"), "running": ("accent", "En cours"), "succeeded": ("good", "Terminée"),
               "partial": ("warn", "Avec erreurs"), "failed": ("crit", "En échec")}

def series(seed, base=40, amp=14, n=24):
    r = random.Random(seed); v = base; out = []
    for _ in range(n):
        v = max(3, min(97, v + r.uniform(-amp, amp) * 0.4)); out.append(v)
    return out

# ============================================================== icons (Heroicons outline)
ICONS = {
    "check": '<path d="M4.5 12.75l6 6 9-13.5"/>',
    "alert": '<path d="M12 9v3.75m0 3.75h.008M10.3 3.86L1.82 18a1.875 1.875 0 001.6 2.82h17.16a1.875 1.875 0 001.6-2.82L13.7 3.86a1.875 1.875 0 00-3.4 0z"/>',
    "x": '<path d="M6 18L18 6M6 6l12 12"/>',
    "off": '<path d="M3 3l18 18M8.5 8.5a5 5 0 017 7M5.6 5.6a9 9 0 0012.8 12.8"/>',
    "server": '<path d="M5.25 14.25h13.5m-13.5 0a3 3 0 01-3-3m3 3a3 3 0 100 6h13.5a3 3 0 100-6m-16.5-3a3 3 0 013-3h13.5a3 3 0 013 3m-19.5 0a4.5 4.5 0 01.9-2.7L5.74 5.3a3 3 0 012.4-1.2h7.72a3 3 0 012.4 1.2l2.49 3.2a4.5 4.5 0 01.9 2.7"/>',
    "grid": '<path d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"/>',
    "key": '<path d="M15.75 5.25a3 3 0 013 3m3 0a6 6 0 01-7.03 5.91c-.57-.1-1.17.03-1.58.44L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.82c0-.6.24-1.17.66-1.59l6.3-6.3c.41-.41.54-1.01.44-1.58A6 6 0 1121.75 8.25z"/>',
    "pulse": '<path d="M3.75 12h3l3-7.5 4.5 15 3-7.5h3"/>',
    "bolt": '<path d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z"/>',
    "cog": '<path d="M10.34 3.94c.09-.54.56-.94 1.11-.94h1.1c.55 0 1.02.4 1.11.94l.15.9c.07.43.38.78.78.95.4.17.86.13 1.21-.13l.74-.53a1.13 1.13 0 011.45.12l.78.78c.39.39.44 1 .12 1.45l-.53.74c-.26.35-.3.81-.13 1.21.17.4.52.71.95.78l.9.15c.54.09.94.56.94 1.11v1.1c0 .55-.4 1.02-.94 1.11l-.9.15a1.24 1.24 0 00-.95.78c-.17.4-.13.86.13 1.21l.53.74c.32.45.27 1.06-.12 1.45l-.78.78a1.13 1.13 0 01-1.45.12l-.74-.53a1.24 1.24 0 00-1.21-.13c-.4.17-.71.52-.78.95l-.15.9c-.09.54-.56.94-1.11.94h-1.1c-.55 0-1.02-.4-1.11-.94l-.15-.9a1.24 1.24 0 00-.78-.95 1.24 1.24 0 00-1.21.13l-.74.53a1.13 1.13 0 01-1.45-.12l-.78-.78a1.13 1.13 0 01-.12-1.45l.53-.74c.26-.35.3-.81.13-1.21a1.24 1.24 0 00-.95-.78l-.9-.15A1.13 1.13 0 013 12.55v-1.1c0-.55.4-1.02.94-1.11l.9-.15c.43-.07.78-.38.95-.78.17-.4.13-.86-.13-1.21l-.53-.74a1.13 1.13 0 01.12-1.45l.78-.78a1.13 1.13 0 011.45-.12l.74.53c.35.26.81.3 1.21.13.4-.17.71-.52.78-.95l.15-.9z"/><path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>',
    "search": '<path d="M21 21l-5.2-5.2M10.5 18a7.5 7.5 0 100-15 7.5 7.5 0 000 15z"/>',
    "refresh": '<path d="M16.02 9.35h4.99V4.36M2.99 19.64v-4.99h4.99M3.6 9.02a8.25 8.25 0 0113.8-3.7l3.18 3.18M20.4 14.98a8.25 8.25 0 01-13.8 3.7l-3.18-3.18"/>',
    "box": '<path d="M20.25 7.5l-.63 10.63a2.25 2.25 0 01-2.24 2.12H6.62a2.25 2.25 0 01-2.24-2.12L3.75 7.5M10 11.25h4M3.38 7.5h17.25c.62 0 1.12-.5 1.12-1.12v-1.5c0-.63-.5-1.13-1.12-1.13H3.38c-.63 0-1.13.5-1.13 1.13v1.5c0 .62.5 1.12 1.13 1.12z"/>',
    "globe": '<path d="M12 21a9 9 0 100-18 9 9 0 000 18zM3.6 9h16.8M3.6 15h16.8M12 3a15 15 0 010 18M12 3a15 15 0 000 18"/>',
    "signal": '<path d="M9.35 14.65a3.75 3.75 0 010-5.3m5.3 0a3.75 3.75 0 010 5.3M7.23 16.77a6.75 6.75 0 010-9.54m9.54 0a6.75 6.75 0 010 9.54M12 12h.01"/>',
    "clock": '<path d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"/>',
    "shield": '<path d="M9 12.75L11.25 15 15 9.75m-3-7.04A11.96 11.96 0 013.6 6 12 12 0 003 9.75c0 5.6 3.82 10.3 9 11.62 5.18-1.33 9-6.03 9-11.62 0-1.31-.21-2.57-.6-3.75h-.15c-3.2 0-6.1-1.25-8.25-3.29z"/>',
    "chevron": '<path d="M8.25 4.5l7.5 7.5-7.5 7.5"/>',
    "plus": '<path d="M12 4.5v15m7.5-7.5h-15"/>',
    "list": '<path d="M8.25 6.75h12M8.25 12h12m-12 5.25h12M3.75 6.75h.007v.008H3.75V6.75zm0 5.25h.007v.008H3.75V12zm0 5.25h.007v.008H3.75v-.008z"/>',
    "copy": '<path d="M8.25 7.5V6.11c0-1.13.84-2.1 1.97-2.19a48.4 48.4 0 017.56 0c1.13.09 1.97 1.06 1.97 2.19V15.4c0 1.13-.84 2.1-1.97 2.19-.3.03-.61.05-.91.07M8.25 7.5h-1.6c-1.13 0-2.1.84-2.19 1.97a48.4 48.4 0 000 7.56c.09 1.13 1.06 1.97 2.19 1.97h7.5c1.13 0 2.1-.84 2.19-1.97a48.4 48.4 0 000-7.56c-.09-1.13-1.06-1.97-2.19-1.97h-5.9z"/>',
    "inbox": '<path d="M2.25 13.5h3.86a2.25 2.25 0 012.01 1.24l.27.53a2.25 2.25 0 002.01 1.23h3.2a2.25 2.25 0 002.01-1.23l.27-.53a2.25 2.25 0 012.01-1.24h3.86M2.25 13.5V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18v-4.5M2.25 13.5l2.45-7.36A2.25 2.25 0 016.83 4.5h10.34a2.25 2.25 0 012.13 1.64l2.45 7.36"/>',
}

def icon(name, cls="h-4 w-4"):
    return f'<svg class="{cls} shrink-0" fill="none" viewBox="0 0 24 24" stroke-width="1.6" stroke="currentColor" aria-hidden="true">{ICONS[name]}</svg>'

def spark(values, w=90, h=22, color="var(--color-spark)"):
    n = len(values)
    pts = [(i * (w - 4) / (n - 1) + 2, h - 2 - v / 100 * (h - 4)) for i, v in enumerate(values)]
    d = " ".join(f"{'M' if i == 0 else 'L'}{x:.1f},{y:.1f}" for i, (x, y) in enumerate(pts))
    return (f'<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" class="overflow-visible"><path d="{d}" fill="none" stroke="{color}" stroke-width="2" '
            f'stroke-linecap="round" stroke-linejoin="round"/><circle cx="{pts[-1][0]:.1f}" cy="{pts[-1][1]:.1f}" r="2.5" fill="{color}"/></svg>')

def chart(values, w=560, h=130, color="var(--color-accent)", warn=None):
    n = len(values); pl, pb = 28, 18; iw, ih = w - pl - 6, h - pb - 6
    pts = [(pl + i * iw / (n - 1), 6 + ih - v / 100 * ih) for i, v in enumerate(values)]
    d = " ".join(f"{'M' if i == 0 else 'L'}{x:.1f},{y:.1f}" for i, (x, y) in enumerate(pts))
    grid = "".join(f'<line x1="{pl}" x2="{w-6}" y1="{6 + ih - g / 100 * ih:.1f}" y2="{6 + ih - g / 100 * ih:.1f}" stroke="var(--color-line)"/>'
                   f'<text x="{pl-6}" y="{6 + ih - g / 100 * ih + 3:.1f}" text-anchor="end" font-size="10" fill="var(--color-ink-3)">{g}</text>' for g in (0, 50, 100))
    thr = f'<line x1="{pl}" x2="{w-6}" y1="{6 + ih - warn / 100 * ih:.1f}" y2="{6 + ih - warn / 100 * ih:.1f}" stroke="var(--color-warn)" stroke-dasharray="3 3"/>' if warn else ""
    xl = "".join(f'<text x="{pl + i * iw / 4:.1f}" y="{h-3}" text-anchor="{"start" if i == 0 else "end" if i == 4 else "middle"}" font-size="10" fill="var(--color-ink-3)">{t}</text>'
                 for i, t in enumerate(["−24 h", "−18 h", "−12 h", "−6 h", "maintenant"]))
    return f'<svg viewBox="0 0 {w} {h}" class="w-full">{grid}{thr}<path d="{d}" fill="none" stroke="{color}" stroke-width="2" stroke-linejoin="round"/>{xl}</svg>'

# ============================================================== pack base
class Pack:
    key = "?"; name = "?"; tagline = ""; idea = ""
    radius = "rounded-xl"; radius_sm = "rounded-lg"; pill = "rounded-full"
    card_cls = "border border-line bg-surface"
    density = "py-2.5"
    head_font = ""
    label_cls = "text-xs text-ink-3"
    nav = [("Vue d'ensemble", "grid", "vue-ensemble"), ("Parc", "server", "parc"), ("Paquets", "box", "paquets"), ("Ports", "globe", "ports"),
           ("Sondes", "signal", "sondes"), ("Trousseau", "key", "trousseau"), ("Activité", "pulse", "activite"), ("Tâches", "clock", "taches"),
           ("Paramètres", "cog", "parametres")]

    # ---------- atoms
    def badge(self, tone, label, ic=None):
        icn = icon(ic, "h-3.5 w-3.5") if ic else ""
        return f'<span class="inline-flex shrink-0 items-center gap-1 whitespace-nowrap {self.pill} bg-{tone}-soft px-2 py-0.5 text-xs font-medium text-{tone}-ink">{icn}{label}</span>'

    def state(self, st): return self.badge(TONE[st], LABEL[st], ICON_OF[st])

    def meter(self, pct, width="w-20", label=None, warn=80, crit=90):
        if pct is None: return '<span class="text-ink-3">—</span>'
        fill = "bg-crit" if pct >= crit else "bg-warn" if pct >= warn else "bg-ink-2"
        lab = f'<span class="w-12 text-xs text-ink-3">{label}</span>' if label else ""
        val = f'<span class="w-9 text-right text-xs tabular-nums {"font-semibold text-crit-ink" if pct >= crit else "text-ink-2"}">{pct:.0f} %</span>'
        return f'<div class="flex items-center gap-2">{lab}<div class="h-1.5 {width} overflow-hidden {self.pill} bg-track"><div class="h-full {self.pill} {fill}" style="width:{pct:.0f}%"></div></div>{val}</div>'

    def btn(self, label, primary=False, ic=None):
        icn = icon(ic) if ic else ""
        cls = "bg-accent text-on-accent hover:opacity-90" if primary else "border border-line bg-surface text-ink"
        return f'<span class="inline-flex items-center gap-1.5 whitespace-nowrap {self.radius_sm} px-3 py-1.5 text-sm font-medium {cls}">{icn}{label}</span>'

    def pills(self, items, active):
        return '<div class="flex flex-wrap gap-2">' + "".join(
            f'<span class="{self.pill} px-3 py-1 text-sm {"bg-ink text-canvas font-medium" if i == active else "border border-line bg-surface text-ink-2"}">{t}</span>' for i, t in enumerate(items)) + "</div>"

    def card(self, title, body, extra="", pad=True):
        head = f'<div class="flex items-center justify-between gap-3 border-b border-line px-4 py-2.5"><h2 class="text-sm font-semibold {self.head_font}">{title}</h2>{extra}</div>' if title else ""
        return f'<section class="{self.radius} {self.card_cls} overflow-hidden">{head}<div class="{"p-4" if pad else ""}">{body}</div></section>'

    def stat(self, label, value, caption="", tone=None, ic=None):
        color = f"text-{tone}-ink" if tone else "text-ink"
        icn = icon(ic, "h-3.5 w-3.5") if ic else ""
        return (f'<div class="{self.radius} {self.card_cls} px-4 py-3"><p class="flex items-center gap-1.5 {self.label_cls}">{icn}{label}</p>'
                f'<p class="mt-1 text-2xl font-semibold tabular-nums {color} {self.head_font}">{value}</p><p class="text-xs text-ink-3">{caption}</p></div>')

    def table(self, headers, rows, cls=""):
        th = "".join(f'<th class="px-3 py-2 font-medium whitespace-nowrap {"pl-4" if i == 0 else ""}">{h}</th>' for i, h in enumerate(headers))
        tr = "".join('<tr class="border-t border-line">' + "".join(f'<td class="px-3 {self.density} align-middle {"pl-4" if i == 0 else ""}">{c}</td>' for i, c in enumerate(r)) + "</tr>" for r in rows)
        return f'<table class="w-full text-left text-sm {cls}"><thead class="bg-subtle text-[11px] uppercase tracking-wide text-ink-3"><tr>{th}</tr></thead><tbody>{tr}</tbody></table>'

    def h1(self, title, sub="", actions=""):
        return (f'<div class="flex flex-wrap items-end justify-between gap-4"><div><h1 class="text-2xl font-semibold tracking-tight {self.head_font}">{title}</h1>'
                f'<p class="mt-0.5 text-sm text-ink-3">{sub}</p></div><div class="flex flex-wrap gap-2">{actions}</div></div>')

    def logo(self):
        return f'<span class="flex items-center gap-2 font-semibold {self.head_font}"><span class="grid h-7 w-7 place-items-center {self.radius_sm} bg-accent text-on-accent">{icon("server")}</span>Elio</span>'

    # ---------- shell (overridden)
    def shell(self, active, body):
        raise NotImplementedError

    # ---------- shared content blocks
    def fleet_rows(self):
        rows = []
        for name, host, group, osn, st, cpu, ram, disk, upd, sec, ports, reason, vulns in FLEET:
            note = f'<span class="text-{TONE[st]}-ink">{reason}</span>' if reason else '<span class="text-ink-3">—</span>'
            upd_html = "—" if upd is None else f'{upd}' + (f' {self.badge("crit", f"{sec} sécu")}' if sec else "")
            rows.append([self.state(st), f'<p class="font-medium">{name}</p><p class="font-mono text-[11px] text-ink-3">{host} · {group}</p>', osn,
                         spark(series(hash(name) % 97, cpu or 20)) if cpu is not None else "—", self.meter(ram), self.meter(disk), upd_html, note])
        return rows

    def fleet_table(self):
        return self.card(None, self.table(["État", "Serveur", "Système", "Charge 24 h", "Mémoire", "Disque", "Mises à jour", "À noter"], self.fleet_rows()), pad=False)

    def attention_list(self, items=None):
        items = items or ATTENTION
        return '<ul class="divide-y divide-line">' + "".join(
            f'<li class="flex items-center gap-3 px-4 py-3"><span class="text-{TONE.get(t, t)}-ink">{icon("x" if t == "crit" else "alert")}</span>'
            f'<p class="flex-1 text-sm"><span class="font-medium">{who}</span> <span class="text-ink-2">— {what}</span></p>{self.btn(a)}</li>' for t, who, what, a in items) + "</ul>"

    def activity_list(self, n=7):
        dots = {"crit": "bg-crit", "warn": "bg-warn", "info": "bg-ink-3"}
        return '<ul class="divide-y divide-line">' + "".join(
            f'<li class="flex items-start gap-3 px-4 py-2.5 text-sm"><span class="mt-1.5 h-2 w-2 {self.pill} {dots[t]}"></span><div class="flex-1"><p>{txt}</p>'
            f'<p class="text-xs text-ink-3">{who} · {by}</p></div><span class="text-xs tabular-nums text-ink-3">{at}</span></li>' for at, t, who, txt, by in ACTIVITY[:n]) + "</ul>"

    def health_block(self):
        cpu, ram, dsk = series(1, 45), series(2, 82, 6), series(3, 90, 3)
        return (f'<div class="grid grid-cols-3 gap-4">{self.stat("Charge", "48 %", "4 processeurs", None, "pulse")}{self.stat("Mémoire", "88 %", "7,1 / 8 Go", "warn")}{self.stat("Disque /", "94 %", "plein dans ≈ 4 jours", "crit")}</div>'
                f'<div class="mt-4 grid grid-cols-3 gap-4">{self.card("Charge 24 h", chart(cpu, warn=None))}{self.card("Mémoire 24 h", chart(ram, warn=80))}{self.card("Disque 24 h", chart(dsk, warn=80))}</div>')

    def system_kv(self):
        kv = [("Système", "Debian GNU/Linux 12 (bookworm) · support jusqu'au 30/06/2028"), ("Noyau", "6.1.0-25-amd64 · x86_64"), ("Hostname", "db-prod.acme.internal"),
              ("Machine", "KVM · 4 processeurs · 8 Go"), ("Démarré", "il y a 41 jours"), ("Adresses", "10.0.1.20 (ens18) · 10.8.0.20 (wg0, WireGuard)")]
        return '<dl class="divide-y divide-line text-sm">' + "".join(f'<div class="flex justify-between gap-4 py-2"><dt class="text-ink-3">{k}</dt><dd class="text-right">{v}</dd></div>' for k, v in kv) + "</dl>"

    def ports_rows(self, with_server=True):
        fw = {"open": self.badge("crit", "non filtré", "x"), "docker": self.badge("warn", "Docker contourne ufw", "alert"), "allowed": self.badge("good", "autorisé", "check")}
        return [[f'<span class="font-mono font-medium">{p}</span>' + (f' {self.badge("warn", "inattendu")}' if unexpected else "")] + ([f'<span class="font-medium">{srv}</span>'] if with_server else []) +
                [f'<span class="font-mono text-xs">{proc}</span>', f'<span class="text-xs text-ink-2">{unit}</span>', fw[state]] for p, srv, proc, unit, state, unexpected in PORTS]

    def packages_rows(self):
        return [[f'<span class="font-medium">{n}</span>', f'<span class="font-mono text-xs">{v}</span>',
                 (f'<span class="font-mono text-xs">→ {u}</span> ' + (self.badge("crit", "sécurité") if sec else "")) if u else '<span class="text-xs text-ink-3">à jour</span>',
                 f'{count} serveurs'] for n, v, u, sec, count in PACKAGES]

    def monitor_rows(self):
        st = {"up": self.badge("good", "En ligne", "check"), "down": self.badge("crit", "Hors ligne", "x")}
        return [[f'<span class="font-medium">{n}</span> <span class="text-xs text-ink-3">{t}</span>', srv or '<span class="text-xs text-warn-ink">non rattachée</span>',
                 f'<span class="font-mono text-xs">{target}</span>' + (f'<span class="block text-[11px] text-ink-3">via {via}</span>' if via else ""), st[s],
                 "—" if rt is None else f"{rt} ms", f"{up:.2f} %".replace(".", ",")] for n, srv, t, target, via, s, rt, up in MONITORS]

    def key_rows(self):
        return [[f'<span class="font-medium">{n}</span>', self.badge("accent", k), f'<span class="font-mono text-xs">{t}</span>', where, f'<span class="font-mono text-[11px] text-ink-3">{fp}</span>']
                for n, k, t, where, fp in KEYS]

    def task_rows(self):
        return [[f'<span class="font-medium">{n}</span>', self.badge(*TASK_STATES[s]), f'<span class="text-xs tabular-nums">{p}</span>', by, at, d] for n, s, p, by, at, d in TASKS]

    def extensions_block(self):
        items = [("Uptime Kuma", "signal", True, "Synchronisé il y a 6 min · 42 sondes"), ("OVHcloud", "globe", True, "Dernière synchronisation impossible : clé expirée"),
                 ("Proxmox", "server", False, "Bientôt")]
        return '<div class="grid grid-cols-3 gap-4">' + "".join(
            f'<div class="{self.radius} {self.card_cls} p-4"><div class="flex items-center justify-between"><p class="flex items-center gap-2 font-semibold">{icon(ic, "h-5 w-5 text-ink-3")}{n}</p>'
            f'{self.badge("good", "Activée") if on else self.badge("neutral", "Désactivée")}</div><p class="mt-2 text-sm text-ink-2">Lecture seule : rattache les ressources aux serveurs.</p>'
            f'<p class="mt-3 text-xs {"text-crit-ink" if "impossible" in note else "text-ink-3"}">{note}</p><div class="mt-4">{self.btn("Configurer")}</div></div>' for n, ic, on, note in items) + "</div>"

    # ---------- pages (overridable)
    def page_overview(self):
        stats = (f'<div class="grid grid-cols-4 gap-3">{self.stat("En ligne", f"{COUNTS["ok"]}/12", "répondent sur SSH", "good", "check")}'
                 f'{self.stat("À surveiller", COUNTS["warn"], "redémarrage, fin de support", "warn", "alert")}{self.stat("Critiques", COUNTS["crit"] + COUNTS["down"], "dont 1 injoignable", "crit", "x")}'
                 f'{self.stat("Vulnérabilités", "27", "dont 9 critiques corrigeables", "crit", "shield")}</div>')
        body = (f'{self.h1("Vue d’ensemble", "12 serveurs · inventoriés il y a 6 min", self.btn("Actualiser", ic="refresh"))}<div class="mt-5">{stats}</div>'
                f'<div class="mt-5 grid grid-cols-3 gap-5"><div class="col-span-2">{self.card("À traiter", self.attention_list(), pad=False)}</div>'
                f'<div>{self.card("Activité récente", self.activity_list(5), pad=False)}</div></div>')
        return self.shell("vue-ensemble", body)

    def page_fleet(self):
        body = (f'{self.h1("Parc", "12 serveurs", self.btn("Actualiser", ic="refresh") + self.btn("Ajouter un serveur", True, "plus"))}'
                f'<div class="mt-5 flex items-center justify-between">{self.pills(["Tous", "Production", "Infra", "Staging"], 0)}<span class="text-xs text-ink-3">Problèmes d’abord</span></div>'
                f'<div class="mt-3">{self.fleet_table()}</div>')
        return self.shell("parc", body)

    def server_header(self):
        return (f'<p class="text-xs text-ink-3">Parc / Production / db-prod</p><div class="mt-1 flex flex-wrap items-center justify-between gap-3"><div class="flex items-center gap-2">'
                f'<h1 class="text-2xl font-semibold {self.head_font}">db-prod</h1>{self.state("crit")}{self.badge("accent", "Production")}</div>'
                f'<div class="flex gap-2">{self.btn("Actualiser l’inventaire", ic="refresh")}{self.btn("Modifier")}</div></div>'
                f'<p class="mt-1 font-mono text-xs text-ink-3">admin@10.0.1.20 · db-prod.acme.internal · Debian 12 · 4 processeurs · 8 Go</p>')

    def tabs(self, active):
        names = ["Vue d’ensemble", "Paquets", "Services", "Ports", "Vulnérabilités", "Clés SSH", "Sondes", "OVH", "Historique"]
        return '<nav class="mt-5 flex gap-5 border-b border-line text-sm">' + "".join(
            f'<span class="-mb-px border-b-2 pb-2.5 {"border-accent font-medium text-ink" if n == active else "border-transparent text-ink-3"}">{n}</span>' for n in names) + "</nav>"

    def page_server(self):
        body = (f'{self.server_header()}{self.tabs("Vue d’ensemble")}<div class="mt-5">{self.health_block()}</div>'
                f'<div class="mt-4 grid grid-cols-2 gap-4">{self.card("Système", self.system_kv())}{self.card("À traiter sur db-prod", self.attention_list(SERVER_ATTENTION), pad=False)}</div>')
        return self.shell("parc", body)

    def page_server_ports(self):
        ufw = "sudo ufw default deny incoming\nsudo ufw allow 22/tcp comment 'ssh'\n# 6432/tcp publié par Docker (pgbouncer) :\n# ufw ne le filtre pas → lier à 10.0.1.20\nsudo ufw enable"
        body = (f'{self.server_header()}{self.tabs("Ports")}<div class="mt-5 grid grid-cols-3 gap-4"><div class="col-span-2">'
                f'{self.card("Ports en écoute", self.table(["Port", "Processus", "Service", "Firewall"], self.ports_rows(False)[2:6]), "<span class=\'text-xs text-ink-3\'>ufw actif</span>", pad=False)}</div>'
                f'<div>{self.card("Règles ufw suggérées", f"<pre class=\'whitespace-pre-wrap rounded-md bg-subtle p-3 font-mono text-[11px] leading-relaxed text-ink-2\'>{ufw}</pre>", self.btn("Copier", ic="copy"))}</div></div>')
        return self.shell("parc", body)

    def page_packages(self):
        body = (f'{self.h1("Paquets", "Recherche sur tout le parc · 7 412 paquets inventoriés")}<div class="mt-4 flex gap-2"><span class="flex w-96 items-center gap-2 {self.radius_sm} border border-line bg-surface px-3 py-1.5 text-sm text-ink-3">{icon("search")}Chercher un paquet…</span></div>'
                f'<div class="mt-4">{self.card("Mises à jour de sécurité en attente", self.table(["Paquet", "Version installée", "Disponible", "Serveurs"], self.packages_rows()), self.badge("crit", "4 paquets"), pad=False)}</div>')
        return self.shell("paquets", body)

    def page_ports(self):
        body = (f'{self.h1("Ports publics", "Ce que chaque serveur expose, les inattendus et non filtrés d’abord")}'
                f'<div class="mt-4">{self.card(None, self.table(["Port", "Serveur", "Processus", "Service", "Firewall"], self.ports_rows()), pad=False)}</div>')
        return self.shell("ports", body)

    def page_monitors(self):
        stats = (f'<div class="grid grid-cols-4 gap-3">{self.stat("Sondes", 42, "", None, "signal")}{self.stat("Hors ligne", 1, "", "crit")}'
                 f'{self.stat("Non rattachées", 3, "à aucun serveur", "warn")}{self.stat("Serveurs sans sonde", 2, "", "warn")}</div>')
        body = (f'{self.h1("Sondes", "Uptime Kuma · synchronisées il y a 6 min")}<div class="mt-4">{stats}</div>'
                f'<div class="mt-4">{self.pills(["Toutes", "Non rattachées", "Hors ligne", "Serveurs sans sonde"], 0)}</div>'
                f'<div class="mt-3">{self.card(None, self.table(["Sonde", "Serveur", "Cible", "État", "Réponse", "Dispo. 30 j"], self.monitor_rows()), pad=False)}</div>')
        return self.shell("sondes", body)

    def page_keyring(self):
        body = (f'{self.h1("Trousseau", "5 clés · personnes et machines", self.btn("Ajouter une clé", True, "plus"))}<div class="mt-4">{self.pills(["Toutes", "Personnes", "Serveurs"], 0)}</div>'
                f'<div class="mt-3">{self.card(None, self.table(["Nom", "Type", "Algorithme", "Accès", "Empreinte"], self.key_rows()), pad=False)}</div>')
        return self.shell("trousseau", body)

    def page_activity(self):
        body = (f'{self.h1("Activité", "Tout ce qui s’est passé, notifiable sur Slack, Discord, email ou webhook")}<div class="mt-4">{self.pills(["Tout", "Clés SSH", "Serveurs", "Sécurité", "Configuration"], 0)}</div>'
                f'<div class="mt-3">{self.card(None, self.activity_list(), pad=False)}</div>')
        return self.shell("activite", body)

    def page_tasks(self):
        body = (f'{self.h1("Tâches", "Inventaires, scans et synchronisations en arrière-plan")}<div class="mt-4">{self.pills(["Toutes", "À venir 0", "En cours 1", "Terminées 2", "En échec 2"], 0)}</div>'
                f'<div class="mt-3">{self.card(None, self.table(["Tâche", "Statut", "Progression", "Lancée par", "Lancée", "Durée"], self.task_rows()), pad=False)}</div>')
        return self.shell("taches", body)

    def page_settings(self):
        tabs = '<nav class="flex gap-1 border-b border-line text-sm">' + "".join(
            f'<span class="-mb-px border-b-2 px-4 py-2 {"border-accent text-accent font-medium" if t == "Extensions" else "border-transparent text-ink-3"}">{t}</span>' for t in ["Général", "Notifications", "Utilisateurs", "Extensions"]) + "</nav>"
        body = f'{self.h1("Paramètres")}<div class="mt-4">{tabs}</div><p class="mt-4 text-sm text-ink-3">Les extensions relient Elio à vos outils, en lecture seule.</p><div class="mt-4">{self.extensions_block()}</div>'
        return self.shell("parametres", body)

    def page_login(self):
        form = (f'<div class="w-full max-w-sm {self.radius} {self.card_cls} p-8">{self.logo()}<h1 class="mt-6 text-xl font-semibold {self.head_font}">Connexion</h1>'
                f'<p class="mt-1 text-sm text-ink-3">Gestionnaire de parc</p>'
                f'<label class="mt-6 block text-sm text-ink-2">Email</label><div class="mt-1 {self.radius_sm} border border-line bg-surface px-3 py-2 text-sm">alice@acme.fr</div>'
                f'<label class="mt-4 block text-sm text-ink-2">Mot de passe</label><div class="mt-1 {self.radius_sm} border border-line bg-surface px-3 py-2 text-sm">••••••••••••</div>'
                f'<div class="mt-6">{self.btn("Se connecter", True).replace("inline-flex", "flex justify-center")}</div><p class="mt-4 text-center text-xs text-ink-3">Mot de passe oublié ?</p></div>')
        return f'<div class="grid min-h-screen place-items-center bg-canvas px-4">{form}</div>'

    def page_mobile_fleet(self):
        rows = "".join(f'<div class="flex items-center gap-3 border-b border-line bg-surface px-4 py-3"><span class="h-2.5 w-2.5 {self.pill} bg-{TONE[s[4]]}"></span><div class="min-w-0 flex-1">'
                       f'<p class="font-medium">{s[0]}</p><p class="truncate text-xs {"text-" + TONE[s[4]] + "-ink" if s[11] else "text-ink-3"}">{s[11] or s[3]}</p></div>{self.meter(s[7], "w-12")}</div>' for s in FLEET[:9])
        return self.mobile_frame("Parc", rows)

    def page_mobile_server(self):
        body = (f'<div class="px-4 py-4">{self.server_header()}</div><div class="space-y-3 px-4">{self.stat("Disque /", "94 %", "plein dans ≈ 4 jours", "crit")}'
                f'{self.stat("Mémoire", "88 %", "7,1 / 8 Go", "warn")}{self.card("À traiter", self.attention_list(SERVER_ATTENTION), pad=False)}</div>')
        return self.mobile_frame("db-prod", body)

    def mobile_frame(self, title, body):
        return (f'<div class="min-h-screen w-[390px] bg-canvas"><div class="flex items-center justify-between border-b border-line bg-surface px-4 py-3">{self.logo()}'
                f'<span class="text-ink-2">{icon("search", "h-5 w-5")}</span></div><h1 class="px-4 pt-4 text-lg font-semibold {self.head_font}">{title}</h1><div class="mt-2">{body}</div></div>')

    PAGES = [("connexion", "Connexion", "page_login"), ("vue-ensemble", "Vue d’ensemble", "page_overview"), ("parc", "Parc", "page_fleet"),
             ("serveur", "Fiche serveur", "page_server"), ("serveur-ports", "Fiche serveur — Ports", "page_server_ports"), ("paquets", "Paquets", "page_packages"),
             ("ports", "Ports", "page_ports"), ("sondes", "Sondes", "page_monitors"), ("trousseau", "Trousseau", "page_keyring"), ("activite", "Activité", "page_activity"),
             ("taches", "Tâches", "page_tasks"), ("parametres", "Paramètres — Extensions", "page_settings")]
    DARK = ["vue-ensemble", "parc", "serveur"]
    MOBILE = [("mobile-parc", "page_mobile_fleet"), ("mobile-serveur", "page_mobile_server")]


# ============================================================== A — Console (current)
class PackA(Pack):
    key, name = "A", "Console"
    tagline = "Barre latérale, tableaux denses, fiche à onglets — l'interface actuelle, affinée."
    idea = "Pour ceux qui vivent dans l'outil : beaucoup d'information par écran, navigation fixe à gauche."
    css = dict(canvas="#f6f6f4", surface="#ffffff", subtle="#f1f1ee", line="#e4e3dd", ink="#121211", ink2="#52514e", ink3="#6f6d68", accent="#4f46e5",
               accent_soft="#eef0ff", on_accent="#ffffff", track="#e9e8e3", spark="#898781",
               dark=dict(canvas="#111110", surface="#1a1a19", subtle="#232321", line="#2e2e2b", ink="#f0efec", ink2="#c3c2b7", ink3="#93918a", accent="#918af2",
                         accent_soft="#24223d", on_accent="#ffffff", track="#2c2c2a", spark="#8f8e86"))

    def shell(self, active, body):
        links = "".join(f'<span class="flex items-center gap-2.5 {self.radius_sm} px-2.5 py-1.5 text-sm {"bg-accent-soft font-medium text-accent" if key == active else "text-ink-2"}">{icon(ic)}{label}</span>'
                        for label, ic, key in self.nav)
        side = (f'<aside class="fixed inset-y-0 left-0 flex w-60 flex-col border-r border-line bg-surface px-3 py-4">{self.logo()}'
                f'<div class="mt-4 flex items-center gap-2 {self.radius_sm} border border-line bg-canvas px-2.5 py-1.5 text-sm text-ink-3">{icon("search")}Rechercher…<span class="ml-auto text-[11px]">⌘K</span></div>'
                f'<nav class="mt-4 space-y-0.5">{links}</nav><div class="mt-auto border-t border-line pt-3 text-xs text-ink-3">alice@acme.fr · Admin</div></aside>')
        return f'{side}<main class="ml-60 px-8 py-6">{body}</main>'


# ============================================================== B — Cartes (airy)
class PackB(Pack):
    key, name = "B", "Cartes"
    tagline = "Navigation en haut, cartes aérées, grands espaces — chaque serveur est une carte."
    idea = "Pour une lecture rapide et agréable : on voit l'état du parc d'un coup d'œil, moins de colonnes, plus de respiration."
    radius, radius_sm = "rounded-2xl", "rounded-xl"
    card_cls = "border border-line bg-surface shadow-[0_1px_2px_rgba(16,24,40,.05)]"
    density = "py-3.5"
    css = dict(canvas="#f7f7fb", surface="#ffffff", subtle="#f2f2f8", line="#e6e6ef", ink="#14142b", ink2="#4e4e6a", ink3="#6e6e89", accent="#5b5bd6",
               accent_soft="#ededfd", on_accent="#ffffff", track="#ececf3", spark="#8b8ba7",
               dark=dict(canvas="#0f0f17", surface="#181824", subtle="#20202e", line="#2a2a3a", ink="#eeeefa", ink2="#bdbdd3", ink3="#8d8da8", accent="#8f8ff5",
                         accent_soft="#25254a", on_accent="#0f0f17", track="#2a2a3a", spark="#8d8da8"))

    def shell(self, active, body):
        top = [(l, ic, k) for l, ic, k in self.nav if k in ("vue-ensemble", "parc", "paquets", "sondes", "trousseau", "activite")]
        links = "".join(f'<span class="{self.radius_sm} px-3 py-1.5 text-sm {"bg-subtle font-medium text-ink" if key == active else "text-ink-2"}">{label}</span>' for label, ic, key in top)
        bar = (f'<header class="border-b border-line bg-surface"><div class="mx-auto flex max-w-7xl items-center gap-6 px-6 py-3">{self.logo()}<nav class="flex gap-1">{links}</nav>'
               f'<div class="ml-auto flex items-center gap-3"><span class="flex w-64 items-center gap-2 {self.radius_sm} border border-line bg-canvas px-3 py-1.5 text-sm text-ink-3">{icon("search")}Rechercher…</span>'
               f'<span class="text-ink-2">{icon("clock", "h-5 w-5")}</span><span class="text-ink-2">{icon("cog", "h-5 w-5")}</span><span class="grid h-8 w-8 place-items-center {self.pill} bg-subtle text-xs font-semibold">AM</span></div></div></header>')
        return f'{bar}<main class="mx-auto max-w-7xl px-6 py-8">{body}</main>'

    def b_card(self, s):
        name, host, group, osn, st, cpu, ram, disk, upd, sec, ports, reason, vulns = s
        border = {"crit": "border-crit/40", "down": "border-crit/40", "warn": "border-warn/50"}.get(st, "border-line")
        inner = (f'<div class="mt-4 grid place-items-center {self.radius_sm} bg-subtle py-7 text-sm text-ink-3">{icon("off")}Pas de réponse depuis 12 min</div>' if st == "down" else
                 f'<div class="mt-4 space-y-2">{self.meter(cpu, "flex-1", "CPU")}{self.meter(ram, "flex-1", "RAM")}{self.meter(disk, "flex-1", "Disque")}</div>')
        foot = f'<p class="mt-4 text-sm text-{TONE[st]}-ink">{reason}</p>' if reason else f'<p class="mt-4 text-sm text-ink-3">{upd} mises à jour · ports {ports}</p>'
        return (f'<article class="{self.radius} border {border} bg-surface p-5 shadow-[0_1px_2px_rgba(16,24,40,.05)]"><div class="flex items-start justify-between gap-2"><div><p class="font-semibold">{name}</p>'
                f'<p class="text-sm text-ink-3">{osn} · {group}</p></div>{self.state(st)}</div>{inner}{foot}</article>')

    def page_fleet(self):
        summary = (f'<div class="{self.radius} {self.card_cls} flex items-center gap-8 px-6 py-5"><p><span class="text-3xl font-semibold text-good-ink">{COUNTS["ok"]}</span> <span class="text-ink-3">en ligne</span></p>'
                   f'<p><span class="text-3xl font-semibold text-warn-ink">{COUNTS["warn"]}</span> <span class="text-ink-3">à surveiller</span></p><p><span class="text-3xl font-semibold text-crit-ink">{COUNTS["crit"] + COUNTS["down"]}</span> <span class="text-ink-3">critiques</span></p>'
                   f'<div class="ml-auto w-72"><div class="flex h-2 gap-0.5"><div class="{self.pill} bg-good" style="flex:7"></div><div class="{self.pill} bg-warn" style="flex:2"></div><div class="{self.pill} bg-crit" style="flex:3"></div></div>'
                   f'<p class="mt-1.5 text-right text-xs text-ink-3">12 serveurs · 57 mises à jour de sécurité</p></div></div>')
        cards = "".join(self.b_card(s) for s in FLEET[:8])
        body = (f'{self.h1("Bonjour Alice", "3 serveurs demandent ton attention.", self.btn("Actualiser", ic="refresh") + self.btn("Ajouter un serveur", True, "plus"))}<div class="mt-6">{summary}</div>'
                f'<div class="mt-6 flex items-center justify-between">{self.pills(["Tous", "Production", "Infra", "Staging"], 0)}<span class="flex gap-1 text-sm"><span class="text-ink-3">{icon("list")}</span><span class="text-ink">{icon("grid")}</span></span></div>'
                f'<div class="mt-4 grid grid-cols-4 gap-4">{cards}</div>')
        return self.shell("parc", body)

    def page_overview(self):
        cards = "".join(self.b_card(s) for s in FLEET[:4])
        body = (f'{self.h1("Bonjour Alice", "Voici l’état du parc ce matin.")}<div class="mt-6 grid grid-cols-3 gap-5"><div class="col-span-2">{self.card("3 choses à faire aujourd’hui", self.attention_list(), pad=False)}</div>'
                f'<div class="space-y-5">{self.stat("Parc en bonne santé", "7 / 12", "3 critiques, 2 à surveiller", "good", "check")}{self.card("Ce qui a changé", self.activity_list(4), pad=False)}</div></div>'
                f'<h2 class="mt-8 text-lg font-semibold">Serveurs à surveiller</h2><div class="mt-3 grid grid-cols-4 gap-4">{cards}</div>')
        return self.shell("vue-ensemble", body)

    def page_server(self):
        sections = "".join(f'<details class="{self.radius} {self.card_cls}" {"open" if i < 2 else ""}><summary class="flex cursor-pointer items-center justify-between px-5 py-4 font-semibold">{t}<span class="text-sm font-normal text-ink-3">{n}</span></summary><div class="border-t border-line p-5">{b}</div></details>'
                           for i, (t, n, b) in enumerate([("Santé", "disque critique", self.health_block()), ("Système", "Debian 12", self.system_kv()), ("Ports", "2 publics", ""), ("Clés SSH", "6 clés", ""), ("Sondes", "1 sonde", "")]))
        body = f'{self.server_header()}<div class="mt-6 space-y-4">{sections}</div>'
        return self.shell("parc", body)

    def page_mobile_fleet(self):
        return self.mobile_frame("Parc", '<div class="space-y-3 px-4">' + "".join(self.b_card(s) for s in FLEET[:4]) + "</div>")


# ============================================================== C — Opérations (inbox / split view)
class PackC(Pack):
    key, name = "C", "Opérations"
    tagline = "Tout part de « À traiter » : boîte de réception des problèmes, liste et fiche côte à côte."
    idea = "Pour l'astreinte : on traite les problèmes un par un sans quitter la page, la liste reste visible."
    radius, radius_sm = "rounded-lg", "rounded-md"
    density = "py-2"
    css = dict(canvas="#f3f5f7", surface="#ffffff", subtle="#eef1f4", line="#dde3e9", ink="#0f1720", ink2="#46525e", ink3="#62707d", accent="#0f766e",
               accent_soft="#e3f4f2", on_accent="#ffffff", track="#e3e8ed", spark="#7d8a96",
               dark=dict(canvas="#0d1216", surface="#141b21", subtle="#1b242b", line="#26313a", ink="#e6edf2", ink2="#b3c0ca", ink3="#86959f", accent="#2dd4bf",
                         accent_soft="#123a37", on_accent="#0d1216", track="#26313a", spark="#86959f"))

    def shell(self, active, body, split=None):
        tabs = "".join(f'<span class="flex items-center gap-1.5 {self.radius_sm} px-2.5 py-1 text-sm {"bg-accent-soft font-medium text-accent" if key == active else "text-ink-2"}">{icon(ic, "h-4 w-4")}{label}</span>'
                       for label, ic, key in self.nav[:8])
        bar = (f'<header class="sticky top-0 z-10 border-b border-line bg-surface"><div class="flex items-center gap-4 px-5 py-2.5">{self.logo()}'
               f'<span class="flex w-[28rem] items-center gap-2 {self.radius_sm} border border-line bg-canvas px-3 py-1.5 text-sm text-ink-3">{icon("search")}Serveur, IP, paquet, port, CVE…<span class="ml-auto text-[11px]">⌘K</span></span>'
               f'<span class="ml-auto flex items-center gap-2 text-sm"><span class="{self.pill} bg-crit px-2 py-0.5 text-xs font-semibold text-on-accent">6</span>à traiter</span></div>'
               f'<nav class="flex gap-1 px-4 pb-2">{tabs}</nav></header>')
        return f'{bar}<main class="px-5 py-5">{body}</main>'

    def c_list(self, selected="db-prod"):
        return "".join(f'<div class="flex items-center gap-3 border-b border-line px-4 py-2.5 {"bg-accent-soft" if s[0] == selected else ""}"><span class="h-2 w-2 {self.pill} bg-{TONE[s[4]]}"></span>'
                       f'<div class="min-w-0 flex-1"><p class="text-sm font-medium">{s[0]}</p><p class="truncate text-xs {"text-" + TONE[s[4]] + "-ink" if s[11] else "text-ink-3"}">{s[11] or s[3] + " · " + s[2]}</p></div>'
                       f'<span class="text-xs tabular-nums text-ink-3">{"" if s[7] is None else str(s[7]) + " %"}</span></div>' for s in FLEET)

    def page_overview(self):
        inbox = "".join(f'<li class="flex items-center gap-3 px-4 py-3 {"bg-accent-soft" if i == 0 else ""}"><span class="text-{TONE.get(t, t)}-ink">{icon("x" if t == "crit" else "alert")}</span>'
                        f'<div class="flex-1"><p class="text-sm"><span class="font-medium">{who}</span></p><p class="text-xs text-ink-2">{what}</p></div><span class="text-xs text-ink-3">il y a {6 + i * 9} min</span></li>' for i, (t, who, what, a) in enumerate(ATTENTION))
        detail = (f'<div class="flex items-center justify-between"><h2 class="text-lg font-semibold">db-prod — Disque / à 94 %</h2>{self.badge("crit", "Critique", "x")}</div>'
                  f'<p class="mt-1 text-sm text-ink-3">Plein dans ≈ 4 jours au rythme actuel (+1,4 %/jour).</p><div class="mt-4">{self.card("Disque / — 24 h", chart(series(3, 90, 3), warn=80))}</div>'
                  f'<div class="mt-4 grid grid-cols-2 gap-3">{self.card("Plus gros dossiers", "<p class=\'text-sm\'>/var/lib/postgresql 61 Go<br>/var/log 9,8 Go<br>/home 2,1 Go</p>")}{self.card("Que faire", "<p class=\'text-sm text-ink-2\'>Purger les journaux, agrandir le volume, ou archiver les vieilles partitions.</p>")}</div>'
                  f'<div class="mt-4 flex gap-2">{self.btn("Ouvrir la fiche", True)}{self.btn("Mettre en sourdine 24 h")}{self.btn("Assigner…")}</div>')
        body = (f'<div class="grid grid-cols-5 gap-5"><div class="col-span-2"><div class="flex items-baseline justify-between"><h1 class="text-xl font-semibold">À traiter</h1><span class="text-xs text-ink-3">6 · par gravité</span></div>'
                f'<ul class="mt-3 divide-y divide-line {self.radius} {self.card_cls}">{inbox}</ul></div><div class="col-span-3 {self.radius} {self.card_cls} p-5">{detail}</div></div>')
        return self.shell("vue-ensemble", body)

    def page_fleet(self):
        body = (f'<div class="grid grid-cols-[22rem_1fr] gap-5"><div class="{self.radius} {self.card_cls} overflow-hidden"><div class="flex items-center justify-between border-b border-line px-4 py-2.5"><p class="font-semibold">Parc <span class="font-normal text-ink-3">12</span></p><span class="text-xs text-ink-3">problèmes d’abord</span></div>{self.c_list()}</div>'
                f'<div>{self.server_header()}<div class="mt-4">{self.health_block()}</div></div></div>')
        return self.shell("parc", body)

    def page_server(self):
        body = (f'<div class="grid grid-cols-[22rem_1fr] gap-5"><div class="{self.radius} {self.card_cls} overflow-hidden">{self.c_list()}</div>'
                f'<div>{self.server_header()}{self.tabs("Vue d’ensemble")}<div class="mt-4 grid grid-cols-2 gap-4">{self.card("Système", self.system_kv())}{self.card("À traiter sur db-prod", self.attention_list(SERVER_ATTENTION), pad=False)}</div></div></div>')
        return self.shell("parc", body)


# ============================================================== D — NOC (dense, technical, dark-first)
class PackD(Pack):
    key, name = "D", "NOC"
    tagline = "Mur de supervision : très dense, chiffres en monospace, pensé pour le sombre et les grands écrans."
    idea = "Pour un écran d'équipe ou l'astreinte de nuit : un maximum de signaux, aucun décor, lisible de loin."
    radius, radius_sm, pill = "rounded-none", "rounded-sm", "rounded-sm"
    card_cls = "border border-line bg-surface"
    density = "py-1.5"
    label_cls = "text-[10px] font-semibold uppercase tracking-widest text-ink-3"
    css = dict(canvas="#eef1f4", surface="#ffffff", subtle="#e6eaef", line="#d3d9e0", ink="#0b1220", ink2="#3a4656", ink3="#5b6878", accent="#0a7d3b",
               accent_soft="#ddf3e6", on_accent="#ffffff", track="#dfe4ea", spark="#5b6878",
               dark=dict(canvas="#07090c", surface="#0d1117", subtle="#131a22", line="#1f2933", ink="#d6dee8", ink2="#a3b1c2", ink3="#7a8899", accent="#3fb950",
                         accent_soft="#10251a", on_accent="#07090c", track="#1f2933", spark="#7a8899"))
    font_body = "mono"

    def shell(self, active, body):
        rail = "".join(f'<span class="grid h-10 w-10 place-items-center {"bg-accent-soft text-accent" if key == active else "text-ink-3"}" title="{label}">{icon(ic, "h-5 w-5")}</span>' for label, ic, key in self.nav)
        bar = (f'<header class="flex items-center gap-4 border-b border-line bg-surface px-4 py-2 font-mono text-xs"><span class="font-semibold text-accent">ELIO</span><span class="text-ink-3">/ {active}</span>'
               f'<span class="ml-6 text-good-ink">● {COUNTS["ok"]} OK</span><span class="text-warn-ink">● {COUNTS["warn"]} WARN</span><span class="text-crit-ink">● {COUNTS["crit"] + COUNTS["down"]} CRIT</span>'
               f'<span class="ml-auto text-ink-3">MAJ 14:08:12 · alice@acme.fr</span></header>')
        return f'{bar}<div class="flex"><nav class="flex w-12 flex-col items-center gap-1 border-r border-line bg-surface py-2" style="min-height:calc(100vh - 33px)">{rail}</nav><main class="flex-1 px-4 py-4 font-mono">{body}</main></div>'

    def h1(self, title, sub="", actions=""):
        return (f'<div class="flex items-end justify-between gap-4 border-b border-line pb-2"><div><h1 class="text-sm font-semibold uppercase tracking-widest">{title}</h1>'
                f'<p class="text-xs text-ink-3">{sub}</p></div><div class="flex gap-2">{actions}</div></div>')

    def tile(self, s):
        name, host, group, osn, st, cpu, ram, disk, *_r, reason, vulns = s
        bg = {"crit": "bg-crit-soft border-crit", "down": "bg-crit-soft border-crit", "warn": "bg-warn-soft border-warn"}.get(st, "bg-surface border-line")
        vals = "OFFLINE" if st == "down" else f"C{cpu:>3} M{ram:>3} D{disk:>3}"
        return (f'<div class="border-l-4 {bg} px-3 py-2"><div class="flex justify-between text-xs"><span class="font-semibold">{name}</span><span class="text-{TONE[st]}-ink">{st.upper()}</span></div>'
                f'<p class="mt-1 whitespace-pre text-[11px] text-ink-2">{vals}</p><p class="truncate text-[11px] text-ink-3">{reason or osn}</p></div>')

    def page_overview(self):
        wall = '<div class="grid grid-cols-6 gap-1">' + "".join(self.tile(s) for s in FLEET) + "</div>"
        body = (f'{self.h1("Vue d’ensemble", "12 serveurs · rafraîchi toutes les 30 s")}<div class="mt-3">{wall}</div>'
                f'<div class="mt-4 grid grid-cols-2 gap-4">{self.card("ALERTES OUVERTES", self.attention_list(), pad=False)}{self.card("FLUX", self.activity_list(), pad=False)}</div>')
        return self.shell("vue-ensemble", body)

    def page_fleet(self):
        wall = '<div class="grid grid-cols-6 gap-1">' + "".join(self.tile(s) for s in FLEET) + "</div>"
        body = f'{self.h1("Parc", "12 serveurs")}<div class="mt-3">{wall}</div><div class="mt-4">{self.fleet_table()}</div>'
        return self.shell("parc", body)


# ============================================================== E — Éditorial (minimal, typographic)
class PackE(Pack):
    key, name = "E", "Éditorial"
    tagline = "Minimal et typographique : peu de cadres, de grands titres, des filets fins, beaucoup de blanc."
    idea = "Pour un outil calme qu'on lit comme un rapport : l'essentiel en phrases, les détails dans des listes sobres."
    radius, radius_sm, pill = "rounded-none", "rounded-none", "rounded-full"
    card_cls = "border-t border-line"
    density = "py-3"
    head_font = "font-display"
    label_cls = "text-xs uppercase tracking-[.18em] text-ink-3"
    css = dict(canvas="#fbfaf7", surface="#fbfaf7", subtle="#f2efe8", line="#e2ddd2", ink="#1c1917", ink2="#57534e", ink3="#78716c", accent="#9a3412",
               accent_soft="#fbeee6", on_accent="#ffffff", track="#e7e2d8", spark="#a8a29e",
               dark=dict(canvas="#151412", surface="#151412", subtle="#1e1c19", line="#2f2c27", ink="#efebe3", ink2="#c9c2b6", ink3="#9a9286", accent="#f59e6c",
                         accent_soft="#3a2418", on_accent="#151412", track="#2f2c27", spark="#9a9286"))

    def shell(self, active, body):
        links = "".join(f'<span class="block py-1 text-sm {"font-semibold text-ink" if key == active else "text-ink-3"}">{label}</span>' for label, ic, key in self.nav)
        side = (f'<aside class="fixed inset-y-0 left-0 w-52 px-8 py-10"><p class="font-display text-2xl">Elio</p><p class="mt-1 text-xs text-ink-3">ACME · 12 serveurs</p>'
                f'<nav class="mt-10">{links}</nav><p class="absolute bottom-8 text-xs text-ink-3">⌘K pour chercher</p></aside>')
        return f'{side}<main class="ml-52 max-w-5xl px-12 py-10">{body}</main>'

    def h1(self, title, sub="", actions=""):
        return (f'<header><h1 class="font-display text-4xl tracking-tight">{title}</h1><p class="mt-2 max-w-2xl text-ink-2">{sub}</p>'
                f'<div class="mt-4 flex gap-4 text-sm">{actions}</div></header>')

    def btn(self, label, primary=False, ic=None):
        return f'<span class="whitespace-nowrap text-sm {"font-semibold text-accent underline underline-offset-4" if primary else "text-ink-2 underline decoration-line underline-offset-4"}">{label}</span>'

    def card(self, title, body, extra="", pad=True):
        head = f'<div class="flex items-baseline justify-between pb-2"><h2 class="text-xs uppercase tracking-[.18em] text-ink-3">{title}</h2>{extra}</div>' if title else ""
        return f'<section class="border-t border-ink pt-3">{head}{body}</section>'

    def table(self, headers, rows, cls=""):
        th = "".join(f'<th class="py-2 pr-4 text-[11px] font-normal uppercase tracking-[.14em] text-ink-3">{h}</th>' for h in headers)
        tr = "".join('<tr class="border-t border-line">' + "".join(f'<td class="py-3 pr-4 align-middle">{c}</td>' for c in r) + "</tr>" for r in rows)
        return f'<table class="w-full text-left text-sm"><thead><tr>{th}</tr></thead><tbody>{tr}</tbody></table>'

    def stat(self, label, value, caption="", tone=None, ic=None):
        color = f"text-{tone}-ink" if tone else "text-ink"
        return f'<div class="border-t border-line pt-3"><p class="{self.label_cls}">{label}</p><p class="mt-1 font-display text-4xl {color}">{value}</p><p class="text-xs text-ink-3">{caption}</p></div>'

    def page_overview(self):
        prose = ('<p class="font-display text-2xl leading-snug">Ce matin, <span class="text-good-ink">sept serveurs vont bien</span>, '
                 '<span class="text-warn-ink">deux demandent un œil</span> et <span class="text-crit-ink">trois sont critiques</span> : le disque de db-prod sera plein dans quatre jours, '
                 'legacy-ftp expose MySQL sur Internet et ci-runner ne répond plus.</p>')
        body = (f'{self.h1("Lundi 1er novembre", "")}<div class="mt-6 max-w-3xl">{prose}</div>'
                f'<div class="mt-10 grid grid-cols-2 gap-12">{self.card("À traiter", self.attention_list())}{self.card("Dans le journal", self.activity_list(5))}</div>')
        return self.shell("vue-ensemble", body)

    def page_fleet(self):
        rows = "".join(f'<div class="grid grid-cols-[1.4fr_1fr_1fr_2fr] items-baseline gap-4 border-t border-line py-3"><p class="font-display text-lg">{s[0]}</p>'
                       f'<p class="text-sm text-ink-3">{s[3]} · {s[2]}</p><p class="text-sm text-{TONE[s[4]]}-ink">{LABEL[s[4]]}</p><p class="text-sm text-ink-2">{s[11] or ("disque " + str(s[7]) + " %, mémoire " + str(s[6]) + " %")}</p></div>' for s in FLEET)
        body = f'{self.h1("Le parc", "Douze serveurs, les problèmes d’abord.", self.btn("Ajouter un serveur", True) + self.btn("Actualiser"))}<div class="mt-8">{rows}</div>'
        return self.shell("parc", body)

    def page_server(self):
        body = (f'{self.h1("db-prod", "Debian 12 sur KVM, 4 processeurs et 8 Go, joignable en 10.0.1.20 et par WireGuard (10.8.0.20). Critique : le disque racine est plein à 94 %.", self.btn("Actualiser l’inventaire", True) + self.btn("Modifier"))}'
                f'<div class="mt-8 grid grid-cols-3 gap-10">{self.stat("Charge", "48 %", "4 processeurs")}{self.stat("Mémoire", "88 %", "7,1 / 8 Go", "warn")}{self.stat("Disque /", "94 %", "plein dans ≈ 4 jours", "crit")}</div>'
                f'<div class="mt-10">{self.card("Disque — 24 h", chart(series(3, 90, 3), warn=80, color="var(--color-accent)"))}</div>'
                f'<div class="mt-10 grid grid-cols-2 gap-12">{self.card("Système", self.system_kv())}{self.card("À traiter sur db-prod", self.attention_list(SERVER_ATTENTION))}</div>')
        return self.shell("parc", body)


PACKS = [PackA(), PackB(), PackC(), PackD(), PackE()]

# ============================================================== output
def theme_css(pack):
    def block(t):
        return "\n".join(f"  --color-{k.replace('_', '-').replace('ink2', 'ink-2').replace('ink3', 'ink-3')}: {v};" for k, v in t.items() if k != "dark")
    common = """  --color-good: #0ca30c; --color-good-soft: #e7f6e7; --color-good-ink: #006300;
  --color-warn: #fab219; --color-warn-soft: #fff4dc; --color-warn-ink: #8a5a00;
  --color-crit: #d03b3b; --color-crit-soft: #fde8e8; --color-crit-ink: #a12424;
  --color-neutral-soft: var(--color-subtle); --color-neutral-ink: var(--color-ink-2);"""
    dark_status = """  --color-good-soft: #13301a; --color-good-ink: #4fd34f; --color-warn-soft: #3a2c0c; --color-warn-ink: #f5c056;
  --color-crit-soft: #3a1717; --color-crit-ink: #f08a8a;"""
    fonts = {"A": ('"Inter", -apple-system, system-ui, sans-serif', '"SF Mono", ui-monospace, Menlo, monospace', 'inherit'),
             "B": ('-apple-system, "SF Pro Text", system-ui, sans-serif', '"SF Mono", ui-monospace, monospace', 'inherit'),
             "C": ('"Segoe UI", -apple-system, system-ui, sans-serif', 'ui-monospace, Menlo, monospace', 'inherit'),
             "D": ('ui-monospace, "SF Mono", Menlo, monospace', 'ui-monospace, "SF Mono", Menlo, monospace', 'inherit'),
             "E": ('"Charter", "Iowan Old Style", Georgia, serif', 'ui-monospace, Menlo, monospace', '"Iowan Old Style", "Charter", Georgia, serif')}[pack.key]
    return f"""@import "tailwindcss";
@source "./{pack.key}/*.html";
@custom-variant dark (&:where(.dark, .dark *));
@theme {{
  --font-sans: {fonts[0]};
  --font-mono: {fonts[1]};
  --font-display: {fonts[2]};
{block(pack.css)}
{common}
}}
.dark {{
{block(pack.css["dark"])}
{dark_status}
}}
"""

def page_html(pack, title, body, dark=False):
    return (f'<!doctype html><html lang="fr" class="{"dark" if dark else ""}"><head><meta charset="utf-8"><title>Elio · {pack.key} · {title}</title>'
            f'<link rel="stylesheet" href="../{pack.key}.out.css"></head><body class="bg-canvas font-sans text-ink antialiased">{body}</body></html>')

def main():
    manifest = []
    for pack in PACKS:
        folder = os.path.join(OUT, pack.key)
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(OUT, f"{pack.key}.input.css"), "w") as f:
            f.write(theme_css(pack))
        for slug, title, method in pack.PAGES:
            body = getattr(pack, method)()
            for dark in ([False, True] if slug in pack.DARK else [False]):
                name = f"{slug}{'-dark' if dark else ''}"
                with open(os.path.join(folder, f"{name}.html"), "w") as f:
                    f.write(page_html(pack, title, body, dark))
                manifest.append((pack.key, name, "desktop"))
        for slug, method in pack.MOBILE:
            with open(os.path.join(folder, f"{slug}.html"), "w") as f:
                f.write(page_html(pack, slug, getattr(pack, method)()))
            manifest.append((pack.key, slug, "mobile"))
    with open(os.path.join(OUT, "manifest.txt"), "w") as f:
        f.write("\n".join(f"{k} {n} {kind}" for k, n, kind in manifest) + "\n")
    gallery()
    print(len(manifest), "pages")

def gallery():
    pages = [(slug, title) for slug, title, _ in Pack.PAGES] + [(s, t) for s, t in [("vue-ensemble-dark", "Vue d’ensemble (sombre)"), ("parc-dark", "Parc (sombre)"),
                                                                                  ("serveur-dark", "Fiche serveur (sombre)"), ("mobile-parc", "Mobile — Parc"), ("mobile-serveur", "Mobile — Fiche")]]
    heads = "".join(f'<th><b>{p.key} — {p.name}</b><br><small>{p.tagline}</small></th>' for p in PACKS)
    rows = "".join(f'<tr><th class="page">{title}</th>' + "".join(f'<td><a href="png/{p.key}-{slug}.jpg"><img loading="lazy" src="png/{p.key}-{slug}.jpg" alt="{p.key} {title}"></a>'
                                                                  f'<a class="src" href="{p.key}/{slug}.html">HTML</a></td>' for p in PACKS) + "</tr>" for slug, title in pages)
    ideas = "".join(f"<li><b>{p.key} — {p.name}</b> : {p.idea}</li>" for p in PACKS)
    html = f"""<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Elio · packs d'interface A–E</title>
<style>body{{font:14px -apple-system,system-ui,sans-serif;margin:24px;color:#1c1917}}table{{border-collapse:collapse}}th,td{{border:1px solid #e5e5e5;padding:8px;vertical-align:top}}
thead th{{position:sticky;top:0;background:#fafafa;width:340px;text-align:left;font-weight:normal}}th.page{{width:140px;text-align:left}}img{{width:320px;display:block;border:1px solid #ddd}}a.src{{font-size:11px;color:#666}}</style></head>
<body><h1>Elio — 5 packs d'interface</h1><p>Chaque colonne est un pack appliqué à toutes les pages ; chaque ligne une page. Cliquez une vignette pour l'agrandir. Choisissez un pack par page (voir <code>PACKS.md</code>).</p><ul>{ideas}</ul>
<table><thead><tr><th class="page">Page</th>{heads}</tr></thead><tbody>{rows}</tbody></table></body></html>"""
    with open(os.path.join(OUT, "index.html"), "w") as f:
        f.write(html)

if __name__ == "__main__":
    main()
