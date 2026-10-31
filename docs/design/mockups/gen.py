# Generates the Elio UI mockups: 3 directions (A, B, C) x pages, light + dark.
import math, os, random

random.seed(7)
OUT = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- data
S = [
    # name, host, user, group, os, state, load, ram, disk, updates, sec, ports, reason
    ("web-prod-1", "51.38.12.4", "deploy", "Production", "Ubuntu 24.04 LTS", "ok", 0.42, 61, 48, 3, 0, "22, 80, 443", None),
    ("web-prod-2", "51.38.12.5", "deploy", "Production", "Ubuntu 24.04 LTS", "ok", 0.37, 58, 51, 3, 0, "22, 80, 443", None),
    ("db-prod", "10.0.1.20", "admin", "Production", "Debian 12", "crit", 1.9, 88, 94, "12", 4, "22, 5432", "Disque / à 94 %"),
    ("cache-prod", "10.0.1.21", "admin", "Production", "Debian 12", "ok", 0.12, 44, 23, 0, 0, "22", None),
    ("worker-1", "10.0.1.30", "deploy", "Production", "Ubuntu 22.04 LTS", "warn", 3.1, 72, 66, 18, 6, "22", "Redémarrage requis"),
    ("worker-2", "10.0.1.31", "deploy", "Production", "Ubuntu 22.04 LTS", "ok", 0.8, 69, 64, 18, 6, "22", None),
    ("backup", "10.0.2.5", "root", "Infra", "Debian 11", "warn", 0.2, 31, 81, 41, 9, "22, 873", "Debian 11 : fin de support"),
    ("monitoring", "10.0.2.8", "root", "Infra", "Debian 12", "ok", 0.55, 63, 39, 2, 0, "22, 3000, 9090", None),
    ("vpn", "37.59.20.11", "root", "Infra", "Ubuntu 24.04 LTS", "ok", 0.05, 22, 18, 0, 0, "22, 51820/udp", None),
    ("staging", "10.0.3.2", "deploy", "Staging", "Ubuntu 24.04 LTS", "ok", 0.3, 47, 57, 5, 1, "22, 80, 443, 8080", None),
    ("ci-runner", "10.0.3.9", "ci", "Staging", "Ubuntu 22.04 LTS", "down", None, None, None, "—", 0, "—", "Injoignable depuis 12 min"),
    ("legacy-ftp", "92.12.4.77", "root", "Infra", "Debian 10", "crit", 0.9, 54, 71, 87, 31, "21, 22, 3306", "MySQL exposé publiquement"),
]
STATE = {
    "ok": ("En ligne", "good", "check"),
    "warn": ("À surveiller", "warn", "alert"),
    "crit": ("Critique", "crit", "x"),
    "down": ("Injoignable", "crit", "off"),
}

def series(n=24, base=40, amp=12, seed=0, trend=0):
    r = random.Random(seed)
    v = base
    out = []
    for i in range(n):
        v = max(2, min(98, v + r.uniform(-amp, amp) * 0.4 + trend))
        out.append(v)
    return out

# ---------------------------------------------------------------- atoms
ICONS = {
    "check": '<path d="M4.5 12.75l6 6 9-13.5"/>',
    "alert": '<path d="M12 9v3.75m0 3.75h.008M10.3 3.86L1.82 18a1.875 1.875 0 001.6 2.82h17.16a1.875 1.875 0 001.6-2.82L13.7 3.86a1.875 1.875 0 00-3.4 0z"/>',
    "x": '<path d="M6 18L18 6M6 6l12 12"/>',
    "off": '<path d="M3 3l18 18M8.5 8.5a5 5 0 017 7M5.6 5.6a9 9 0 0012.8 12.8"/>',
    "server": '<path d="M5.25 14.25h13.5m-13.5 0a3 3 0 01-3-3m3 3a3 3 0 100 6h13.5a3 3 0 100-6m-16.5-3a3 3 0 013-3h13.5a3 3 0 013 3m-19.5 0a4.5 4.5 0 01.9-2.7L5.74 5.3a3 3 0 012.4-1.2h7.72a3 3 0 012.4 1.2l2.49 3.2a4.5 4.5 0 01.9 2.7m0 0a3 3 0 01-3 3m0 3h.008v.008h-.008v-.008zm0-6h.008v.008h-.008v-.008zm-3 6h.008v.008h-.008v-.008zm0-6h.008v.008h-.008v-.008z"/>',
    "key": '<path d="M15.75 5.25a3 3 0 013 3m3 0a6 6 0 01-7.03 5.91c-.57-.1-1.17.03-1.58.44L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.82c0-.6.24-1.17.66-1.59l6.3-6.3c.41-.41.54-1.01.44-1.58A6 6 0 1121.75 8.25z"/>',
    "activity": '<path d="M3.75 12h3l3-7.5 4.5 15 3-7.5h3"/>',
    "bolt": '<path d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z"/>',
    "cog": '<path d="M9.6 3.94c.09-.54.56-.94 1.11-.94h2.59c.55 0 1.02.4 1.11.94l.21 1.28c.06.37.31.68.65.87l.33.19c.34.2.75.24 1.1.1l1.22-.45a1.13 1.13 0 011.37.49l1.3 2.24c.27.48.16 1.08-.27 1.43l-1 .83c-.29.24-.43.6-.42.98v.38c0 .37.14.73.42.97l1 .83c.43.35.54.95.27 1.43l-1.3 2.24a1.13 1.13 0 01-1.37.49l-1.22-.45c-.35-.13-.75-.09-1.1.1l-.33.19c-.34.2-.59.5-.65.87l-.21 1.28c-.09.54-.56.94-1.11.94h-2.59c-.55 0-1.02-.4-1.11-.94l-.21-1.28a1.24 1.24 0 00-.65-.87l-.33-.19a1.24 1.24 0 00-1.1-.1l-1.22.45a1.13 1.13 0 01-1.37-.49l-1.3-2.24a1.13 1.13 0 01.27-1.43l1-.83c.29-.24.43-.6.42-.97v-.38c0-.37-.14-.73-.42-.98l-1-.83a1.13 1.13 0 01-.27-1.43l1.3-2.24a1.13 1.13 0 011.37-.49l1.22.45c.35.13.75.1 1.1-.1l.33-.19c.34-.19.59-.5.65-.87l.21-1.28z"/><path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>',
    "search": '<path d="M21 21l-5.2-5.2M10.5 18a7.5 7.5 0 100-15 7.5 7.5 0 000 15z"/>',
    "refresh": '<path d="M16.02 9.35h4.99V4.36M2.99 19.64v-4.99h4.99M3.6 9.02a8.25 8.25 0 0113.8-3.7l3.18 3.18M20.4 14.98a8.25 8.25 0 01-13.8 3.7l-3.18-3.18"/>',
    "box": '<path d="M20.25 7.5l-.63 10.63a2.25 2.25 0 01-2.24 2.12H6.62a2.25 2.25 0 01-2.24-2.12L3.75 7.5M10 11.25h4M3.38 7.5h17.25c.62 0 1.12-.5 1.12-1.12v-1.5c0-.63-.5-1.13-1.12-1.13H3.38c-.63 0-1.13.5-1.13 1.13v1.5c0 .62.5 1.12 1.13 1.12z"/>',
    "plug": '<path d="M13.19 8.69a4.5 4.5 0 011.24 7.24l-4.5 4.5a4.5 4.5 0 01-6.36-6.36l1.76-1.76m13.35-.62l1.76-1.76a4.5 4.5 0 00-6.36-6.36l-4.5 4.5a4.5 4.5 0 001.24 7.24"/>',
    "list": '<path d="M8.25 6.75h12M8.25 12h12m-12 5.25h12M3.75 6.75h.007v.008H3.75V6.75zm0 5.25h.007v.008H3.75V12zm0 5.25h.007v.008H3.75v-.008z"/>',
    "clock": '<path d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"/>',
    "shield": '<path d="M9 12.75L11.25 15 15 9.75m-3-7.04A11.96 11.96 0 013.6 6 12 12 0 003 9.75c0 5.6 3.82 10.3 9 11.62 5.18-1.33 9-6.03 9-11.62 0-1.31-.21-2.57-.6-3.75h-.15c-3.2 0-6.1-1.25-8.25-3.29z"/>',
    "chevron": '<path d="M8.25 4.5l7.5 7.5-7.5 7.5"/>',
    "down": '<path d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>',
    "plus": '<path d="M12 4.5v15m7.5-7.5h-15"/>',
    "sun": '<path d="M12 3v2.25m6.36.39l-1.59 1.59M21 12h-2.25m-.39 6.36l-1.59-1.59M12 18.75V21m-4.77-4.23l-1.59 1.59M5.25 12H3m4.23-4.77L5.64 5.64M15.75 12a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z"/>',
    "folder": '<path d="M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-8.69-6.44l-2.12-2.12a1.5 1.5 0 00-1.06-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.38a1.5 1.5 0 01-1.06-.44z"/>',
    "copy": '<path d="M15.75 17.25v3.38c0 .62-.5 1.12-1.12 1.12h-9.75a1.13 1.13 0 01-1.13-1.12V7.88c0-.63.5-1.13 1.13-1.13H6.75a9.06 9.06 0 011.5.12m7.5 10.38h3.38c.62 0 1.12-.5 1.12-1.13V11.25c0-4.46-3.24-8.16-7.5-8.87a9.06 9.06 0 00-1.5-.13H9.38c-.62 0-1.12.5-1.12 1.13v3.5m7.5 10.37H9.38c-.63 0-1.13-.5-1.13-1.12v-9.25m12 6.62v-1.88a3.38 3.38 0 00-3.37-3.37h-1.5a1.13 1.13 0 01-1.13-1.13v-1.5a3.38 3.38 0 00-3.37-3.37H8.25"/>',
}

def icon(name, cls="h-4 w-4"):
    return f'<svg class="{cls} shrink-0" fill="none" viewBox="0 0 24 24" stroke-width="1.6" stroke="currentColor" aria-hidden="true">{ICONS[name]}</svg>'

def status(state, size="sm"):
    label, tone, ic = STATE[state]
    pad = "px-2 py-0.5 text-xs" if size == "sm" else "px-2.5 py-1 text-sm"
    return (f'<span class="inline-flex shrink-0 items-center gap-1 whitespace-nowrap rounded-full bg-{tone}-soft {pad} font-medium text-{tone}-ink">'
            f'{icon(ic, "h-3.5 w-3.5")}{label}</span>')

def dot(state):
    tone = STATE[state][1]
    return f'<span class="inline-block h-2 w-2 rounded-full bg-{tone}" title="{STATE[state][0]}"></span>'

def tone_for(pct, warn=80, crit=90):
    if pct is None: return "track"
    return "crit" if pct >= crit else "warn" if pct >= warn else "accent"

def meter(pct, label=None, width="w-24", show_value=True):
    if pct is None:
        return '<span class="text-ink-3">—</span>'
    tone = tone_for(pct)
    fill = {"accent": "bg-ink-2", "warn": "bg-warn", "crit": "bg-crit"}[tone]
    val = f'<span class="w-9 text-right tabular-nums text-xs {"font-semibold text-crit-ink" if tone=="crit" else "text-ink-2"}">{pct:.0f} %</span>' if show_value else ""
    lab = f'<span class="w-12 text-xs text-ink-3">{label}</span>' if label else ""
    return (f'<div class="flex items-center gap-2">{lab}<div class="h-1.5 {width} overflow-hidden rounded-full bg-track">'
            f'<div class="h-full rounded-full {fill}" style="width:{pct:.0f}%"></div></div>{val}</div>')

def spark(values, w=96, h=24, stroke="var(--color-spark)", last_dot=True, fill=False, vmax=100):
    n = len(values)
    pts = [(i * (w - 4) / (n - 1) + 2, h - 2 - (v / vmax) * (h - 4)) for i, v in enumerate(values)]
    d = " ".join(f"{'M' if i == 0 else 'L'}{x:.1f},{y:.1f}" for i, (x, y) in enumerate(pts))
    area = ""
    if fill:
        area = f'<path d="{d} L{pts[-1][0]:.1f},{h} L{pts[0][0]:.1f},{h} Z" fill="{stroke}" opacity="0.10"/>'
    end = f'<circle cx="{pts[-1][0]:.1f}" cy="{pts[-1][1]:.1f}" r="2.5" fill="{stroke}"/>' if last_dot else ""
    return (f'<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" class="overflow-visible">{area}'
            f'<path d="{d}" fill="none" stroke="{stroke}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>{end}</svg>')

def chart(values, w=520, h=120, color="var(--color-accent)", vmax=100, label_unit="%", warn=None):
    n = len(values)
    pad_l, pad_b = 28, 18
    iw, ih = w - pad_l - 6, h - pad_b - 6
    pts = [(pad_l + i * iw / (n - 1), 6 + ih - (v / vmax) * ih) for i, v in enumerate(values)]
    d = " ".join(f"{'M' if i == 0 else 'L'}{x:.1f},{y:.1f}" for i, (x, y) in enumerate(pts))
    grid = ""
    for g in (0, 50, 100):
        y = 6 + ih - g / vmax * ih
        grid += f'<line x1="{pad_l}" x2="{w-6}" y1="{y:.1f}" y2="{y:.1f}" stroke="var(--color-line)" stroke-width="1"/>'
        grid += f'<text x="{pad_l-6}" y="{y+3:.1f}" text-anchor="end" font-size="10" fill="var(--color-ink-3)">{g}</text>'
    thr = ""
    if warn:
        y = 6 + ih - warn / vmax * ih
        thr = (f'<line x1="{pad_l}" x2="{w-6}" y1="{y:.1f}" y2="{y:.1f}" stroke="var(--color-warn)" stroke-width="1" stroke-dasharray="3 3"/>'
               f'<text x="{pad_l+6}" y="{y+13:.1f}" font-size="10" fill="var(--color-ink-3)">seuil {warn} %</text>')
    xl = "".join(f'<text x="{pad_l + i*iw/4:.1f}" y="{h-3}" text-anchor="{"start" if i == 0 else "end" if i == 4 else "middle"}" font-size="10" fill="var(--color-ink-3)">{t}</text>'
                 for i, t in enumerate(["−24 h", "−18 h", "−12 h", "−6 h", "maintenant"]))
    area = f'<path d="{d} L{pts[-1][0]:.1f},{6+ih} L{pts[0][0]:.1f},{6+ih} Z" fill="{color}" opacity="0.08"/>'
    return (f'<svg viewBox="0 0 {w} {h}" width="{w}" height="{h}" class="max-w-full" role="img">{grid}{thr}{area}'
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="2" stroke-linejoin="round"/>'
            f'<circle cx="{pts[-1][0]:.1f}" cy="{pts[-1][1]:.1f}" r="3.5" fill="{color}" stroke="var(--color-surface)" stroke-width="2"/>{xl}</svg>')

def os_label(os_name):
    eol = os_name in ("Debian 10", "Debian 11")
    style = "text-crit-ink" if os_name == "Debian 10" else "text-warn-ink" if eol else "text-ink-2"
    return f'<span class="{style}">{os_name}</span>'

def page(title, body, dark=False, body_cls="bg-canvas text-ink"):
    return f"""<!DOCTYPE html><html lang="fr" class="{'dark' if dark else ''}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>{title}</title><link rel="stylesheet" href="out.css"></head>
<body class="{body_cls} font-sans text-sm antialiased">{body}</body></html>"""

def write(name, title, body, **kw):
    for dark in (False, True):
        fn = f"{name}{'-dark' if dark else ''}.html"
        with open(os.path.join(OUT, fn), "w") as f:
            f.write(page(title, body, dark=dark, **kw))

def logo(cls="text-base"):
    return (f'<div class="flex items-center gap-2 font-semibold tracking-tight {cls}">'
            '<span class="grid h-7 w-7 place-items-center rounded-lg bg-accent text-white">'
            '<svg viewBox="0 0 24 24" class="h-4 w-4" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M5 6h14M5 12h10M5 18h14"/></svg></span>Elio</div>')

counts = {"ok": sum(1 for s in S if s[5] == "ok"), "warn": sum(1 for s in S if s[5] == "warn"),
          "crit": sum(1 for s in S if s[5] == "crit"), "down": sum(1 for s in S if s[5] == "down")}

# ---------------------------------------------------------------- shared server detail data
DB = S[2]
PACKAGES = [("postgresql-15", "15.8-0+deb12u1", "15.10-0+deb12u1", True), ("openssl", "3.0.14-1~deb12u1", "3.0.15-1~deb12u1", True),
            ("linux-image-amd64", "6.1.106-3", "6.1.115-1", True), ("nginx", "1.22.1-9", None, False), ("curl", "7.88.1-10+deb12u7", "7.88.1-10+deb12u8", True),
            ("docker-ce", "5:27.3.1-1~debian.12", None, False), ("vim", "2:9.0.1378-2", None, False), ("python3", "3.11.2-1+b1", None, False)]
SERVICES = [("postgresql@15-main", "actif", "ok", "PostgreSQL Cluster 15-main"), ("pgbackrest.timer", "actif", "ok", "Sauvegarde PostgreSQL"),
            ("node-exporter", "actif", "ok", "Prometheus node exporter"), ("fail2ban", "en échec", "crit", "Fail2Ban Service"),
            ("ssh", "actif", "ok", "OpenBSD Secure Shell server"), ("unattended-upgrades", "inactif", "warn", "Mises à jour automatiques")]
CONTAINERS = [("pgadmin", "dpage/pgadmin4:8.12", "En cours", "ops-tools", "/opt/ops-tools/compose.yml"),
              ("pgbouncer", "edoburu/pgbouncer:1.23", "En cours", "ops-tools", "/opt/ops-tools/compose.yml")]
PORTS = [("22", "tcp", "0.0.0.0", "public", "sshd", "ssh.service", True), ("5432", "tcp", "10.0.1.20", "privé", "postgres", "postgresql@15-main", True),
         ("6432", "tcp", "0.0.0.0", "public", "docker-proxy", "pgbouncer (ops-tools)", False), ("5050", "tcp", "127.0.0.1", "local", "docker-proxy", "pgadmin (ops-tools)", True),
         ("9100", "tcp", "0.0.0.0", "public", "node_exporter", "node-exporter", False), ("53", "udp", "127.0.0.53", "local", "systemd-resolve", "systemd-resolved", True)]
KEYS = [("Alice Martin", "Personne", "ed25519", None), ("Bastien Roy", "Personne", "ed25519", "Expire dans 2 h"),
        ("ci-runner", "Serveur", "ed25519", None), ("Clé Elio", "Elio", "ed25519", None), ("jdupont@old-laptop", None, "rsa", None)]
HISTORY = [("il y a 14 min", "crit", "Disque / à 94 % (seuil critique 90 %)"), ("il y a 2 h", "warn", "fail2ban : service en échec"),
           ("il y a 6 h", "info", "4 mises à jour de sécurité disponibles"), ("hier", "info", "Clé « Bastien Roy » ajoutée pour 24 h par alice@acme.fr"),
           ("il y a 3 j", "info", "Port 6432/tcp ouvert (pgbouncer)")]

def kv(rows):
    return '<dl class="divide-y divide-line">' + "".join(
        f'<div class="flex justify-between gap-4 py-2"><dt class="text-ink-3">{k}</dt><dd class="text-right text-ink">{v}</dd></div>' for k, v in rows) + "</dl>"

SYSTEM_ROWS = [("Système", 'Debian 12 « bookworm » <span class="text-ink-3">· support jusqu\'en juin 2028</span>'),
               ("Noyau", '<span class="font-mono text-xs">6.1.0-25-amd64</span> <span class="text-warn-ink">→ 6.1.0-27 au redémarrage</span>'),
               ("Matériel", "8 vCPU · 32 Go · KVM"), ("Démarré", "il y a 41 jours"), ("Fuseau / NTP", "Europe/Paris · synchronisé"),
               ("Accès root", '<span class="text-good-ink">sudo sans mot de passe</span>')]

def ports_table(compact=False):
    head = "".join(f'<th class="px-3 py-2 font-medium">{h}</th>' for h in ["Port", "Écoute", "Exposition", "Processus", "Service / conteneur", "Firewall"])
    rows = ""
    for port, proto, addr, exp, proc, svc, allowed in PORTS:
        exp_cls = {"public": "bg-crit-soft text-crit-ink" if not allowed else "bg-warn-soft text-warn-ink", "privé": "bg-subtle text-ink-2", "local": "bg-subtle text-ink-3"}[exp]
        fw = ('<span class="inline-flex items-center gap-1 text-good-ink">' + icon("check", "h-3.5 w-3.5") + "autorisé</span>") if allowed and exp == "public" else \
             ('<span class="inline-flex items-center gap-1 text-crit-ink">' + icon("alert", "h-3.5 w-3.5") + "non filtré</span>") if exp == "public" else '<span class="text-ink-3">—</span>'
        rows += (f'<tr class="border-t border-line"><td class="px-3 py-2 font-mono font-medium">{port}<span class="text-ink-3">/{proto}</span></td>'
                 f'<td class="px-3 py-2 font-mono text-xs text-ink-2">{addr}</td><td class="px-3 py-2"><span class="rounded px-1.5 py-0.5 text-xs font-medium {exp_cls}">{exp}</span></td>'
                 f'<td class="whitespace-nowrap px-3 py-2 font-mono text-xs">{proc}</td><td class="whitespace-nowrap px-3 py-2 text-ink-2">{svc}</td><td class="whitespace-nowrap px-3 py-2 text-xs">{fw}</td></tr>')
    return f'<table class="w-full text-left text-sm"><thead class="text-xs text-ink-3"><tr>{head}</tr></thead><tbody>{rows}</tbody></table>'

def keys_list():
    out = ""
    for name, kind, algo, exp in KEYS:
        if kind is None:
            badge = '<span class="rounded-full bg-warn-soft px-2 py-0.5 text-xs font-medium text-warn-ink">Hors trousseau</span>'
            action = '<button class="rounded-md border border-line px-2 py-1 text-xs font-medium">Ajouter au trousseau</button>'
        elif kind == "Elio":
            badge = '<span class="rounded-full bg-accent px-2 py-0.5 text-xs font-medium text-white">Elio</span>'
            action = ""
        else:
            badge = f'<span class="rounded-full bg-subtle px-2 py-0.5 text-xs text-ink-2">{kind}</span>'
            action = '<button class="text-xs text-ink-3">Retirer</button>'
        expb = f'<span class="rounded-full bg-warn-soft px-2 py-0.5 text-xs text-warn-ink">{exp}</span>' if exp else ""
        out += (f'<li class="flex items-center gap-3 py-2.5">{icon("key", "h-4 w-4 text-ink-3")}<span class="font-medium">{name}</span>{badge}{expb}'
                f'<span class="ml-auto font-mono text-xs text-ink-3">{algo}</span>{action}</li>')
    return f'<ul class="divide-y divide-line">{out}</ul>'

def packages_list(n=8):
    out = ""
    for name, ver, new, sec in PACKAGES[:n]:
        upd = (f'<span class="font-mono text-xs text-ink-2">→ {new}</span>' + (' <span class="rounded bg-crit-soft px-1.5 py-0.5 text-[11px] font-medium text-crit-ink">sécurité</span>' if sec else "")) if new else '<span class="text-xs text-ink-3">à jour</span>'
        out += f'<tr class="border-t border-line"><td class="px-3 py-2 font-medium">{name}</td><td class="px-3 py-2 font-mono text-xs text-ink-2">{ver}</td><td class="px-3 py-2">{upd}</td></tr>'
    return f'<table class="w-full text-left text-sm"><thead class="text-xs text-ink-3"><tr><th class="px-3 py-2 font-medium">Paquet</th><th class="px-3 py-2 font-medium">Version</th><th class="px-3 py-2 font-medium">Mise à jour</th></tr></thead><tbody>{out}</tbody></table>'

def services_list():
    out = ""
    for name, st, tone, desc in SERVICES:
        ic = {"ok": "check", "warn": "alert", "crit": "x"}[tone]
        out += (f'<li class="flex items-center gap-3 py-2"><span class="inline-flex w-24 items-center gap-1 text-xs font-medium text-{tone}-ink">{icon(ic, "h-3.5 w-3.5")}{st}</span>'
                f'<span class="font-mono text-xs">{name}</span><span class="ml-auto truncate text-xs text-ink-3">{desc}</span></li>')
    return f'<ul class="divide-y divide-line">{out}</ul>'

def history_list():
    out = ""
    for when, tone, text in HISTORY:
        c = {"crit": "bg-crit", "warn": "bg-warn", "info": "bg-ink-3"}[tone]
        out += f'<li class="flex gap-3 py-2"><span class="mt-1.5 h-2 w-2 shrink-0 rounded-full {c}"></span><span class="flex-1">{text}</span><span class="shrink-0 text-xs text-ink-3">{when}</span></li>'
    return f'<ul>{out}</ul>'

def card(title, body, extra="", cls=""):
    return (f'<section class="rounded-xl border border-line bg-surface {cls}"><div class="flex items-center justify-between border-b border-line px-4 py-2.5">'
            f'<h3 class="text-sm font-semibold">{title}</h3>{extra}</div><div class="px-4 py-3">{body}</div></section>')

def btn(text, ic=None, primary=False):
    cls = "bg-accent text-white" if primary else "border border-line bg-surface text-ink"
    return f'<button class="inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm font-medium {cls}">{icon(ic) if ic else ""}{text}</button>'

def count_html(n):
    return f'<span class="ml-auto text-xs text-ink-3">{n}</span>' if n else ""

def tab_count(n):
    return f'<span class="rounded-full bg-subtle px-1.5 text-[11px] text-ink-2">{n}</span>' if n else ""

# ================================================================ A — Console (sidebar + table + tabs)
def a_sidebar(active):
    items = [("Parc", "server", "12"), ("Trousseau", "key", "9"), ("Activité", "activity", None), ("Automatisations", "bolt", None), ("Paramètres", "cog", None)]
    nav = ""
    for label, ic, n in items:
        on = label == active
        nav += (f'<a class="flex items-center gap-2.5 rounded-lg px-2.5 py-1.5 {"bg-accent-soft font-medium text-accent" if on else "text-ink-2"}">'
                f'{icon(ic)}{label}{count_html(n)}</a>')
    groups = "".join(f'<a class="flex items-center gap-2 px-2.5 py-1 text-ink-2"><span class="h-2 w-2 rounded-full {c}"></span>{g}<span class="ml-auto text-xs text-ink-3">{n}</span></a>'
                     for g, c, n in [("Production", "bg-[#2a78d6]", 6), ("Infra", "bg-[#1baf7a]", 4), ("Staging", "bg-[#eda100]", 2)])
    return f"""<aside class="flex w-60 shrink-0 flex-col border-r border-line bg-surface px-3 py-4">
      {logo()}
      <div class="mt-5 flex items-center gap-2 rounded-lg border border-line bg-canvas px-2.5 py-1.5 text-ink-3">{icon("search")}Rechercher<kbd class="ml-auto rounded border border-line px-1 text-[10px]">⌘K</kbd></div>
      <nav class="mt-4 space-y-0.5">{nav}</nav>
      <p class="mt-6 px-2.5 text-[11px] font-semibold uppercase tracking-wider text-ink-3">Groupes</p>
      <div class="mt-1 space-y-0.5">{groups}</div>
      <div class="mt-auto flex items-center gap-2 rounded-lg px-2.5 py-2 text-ink-2"><span class="grid h-7 w-7 place-items-center rounded-full bg-subtle text-xs font-semibold">AM</span><div class="leading-tight"><p class="text-xs font-medium text-ink">alice@acme.fr</p><p class="text-[11px] text-ink-3">Admin</p></div></div>
    </aside>"""

def stat_tile(label, value, sub, tone=None, ic=None):
    accent = f"text-{tone}-ink" if tone else "text-ink"
    return (f'<div class="rounded-xl border border-line bg-surface px-4 py-3"><p class="flex items-center gap-1.5 text-xs text-ink-3">{icon(ic, "h-3.5 w-3.5") if ic else ""}{label}</p>'
            f'<p class="mt-1 text-2xl font-semibold tabular-nums {accent}">{value}</p><p class="text-xs text-ink-3">{sub}</p></div>')

def a_fleet():
    rows = ""
    for i, (name, host, user, group, osn, st, load, ram, disk, upd, sec, ports, reason) in enumerate(S):
        cpu = spark(series(18, 30 if st != "crit" else 60, 18, seed=i), w=72, h=20) if load is not None else '<span class="text-ink-3">—</span>'
        updc = f'<span class="tabular-nums">{upd}</span>' + (f' <span class="rounded bg-crit-soft px-1 text-[11px] font-medium text-crit-ink">{sec} sécu</span>' if sec else "")
        sel = "bg-accent-soft/60" if name == "db-prod" else ""
        rows += f"""<tr class="border-t border-line {sel}">
          <td class="py-2 pl-4 pr-2">{status(st)}</td>
          <td class="px-2 py-2"><p class="font-medium">{name}</p><p class="font-mono text-[11px] text-ink-3">{user}@{host}</p></td>
          <td class="px-2 py-2 text-xs">{os_label(osn)}</td>
          <td class="px-2 py-2">{cpu}</td>
          <td class="px-2 py-2">{meter(ram, width="w-16")}</td>
          <td class="px-2 py-2">{meter(disk, width="w-16")}</td>
          <td class="px-2 py-2 text-xs">{updc}</td>
          <td class="px-2 py-2 font-mono text-[11px] text-ink-2">{ports}</td>
          <td class="px-2 py-2 pr-4 text-xs text-ink-2">{reason or '<span class="text-ink-3">—</span>'}</td></tr>"""
    tiles = (stat_tile("En ligne", f'{counts["ok"]}<span class="text-base text-ink-3">/12</span>', "joignables et sains", "good", "check")
             + stat_tile("À surveiller", counts["warn"], "redémarrage, fin de support", "warn", "alert")
             + stat_tile("Critiques", counts["crit"] + counts["down"], "dont 1 injoignable", "crit", "x")
             + stat_tile("Mises à jour sécurité", "57", "sur 7 serveurs", None, "shield"))
    chips = "".join(f'<span class="rounded-full px-2.5 py-1 text-xs {"bg-ink text-canvas font-medium" if c == "Tous" else "border border-line bg-surface text-ink-2"}">{c}</span>'
                    for c in ["Tous", "Production", "Infra", "Staging"])
    body = f"""<div class="flex h-screen">{a_sidebar("Parc")}
    <main class="min-w-0 flex-1 overflow-auto px-8 py-6">
      <div class="flex items-center justify-between"><div><h1 class="text-xl font-semibold">Parc</h1><p class="text-xs text-ink-3">12 serveurs · inventaire il y a 14 min</p></div>
        <div class="flex gap-2">{btn("Actualiser", "refresh")}{btn("Ajouter un serveur", "plus", True)}</div></div>
      <div class="mt-5 grid grid-cols-4 gap-3">{tiles}</div>
      <div class="mt-5 flex items-center gap-2">{chips}<span class="mx-2 h-4 w-px bg-line"></span>
        <span class="inline-flex items-center gap-1 rounded-lg border border-line bg-surface px-2.5 py-1 text-xs text-ink-2">Système : tous {icon("down", "h-3 w-3")}</span>
        <span class="inline-flex items-center gap-1 rounded-lg border border-line bg-surface px-2.5 py-1 text-xs text-ink-2">État : tous {icon("down", "h-3 w-3")}</span>
        <div class="ml-auto flex items-center gap-2 rounded-lg border border-line bg-surface px-2.5 py-1 text-xs text-ink-3">{icon("search", "h-3.5 w-3.5")}Filtrer par nom, IP, paquet…</div></div>
      <div class="mt-3 overflow-hidden rounded-xl border border-line bg-surface">
        <table class="w-full text-left"><thead class="bg-subtle text-[11px] uppercase tracking-wide text-ink-3"><tr>
          <th class="py-2 pl-4 pr-2 font-medium">État</th><th class="px-2 py-2 font-medium">Serveur</th><th class="px-2 py-2 font-medium">Système</th><th class="px-2 py-2 font-medium">CPU 24 h</th>
          <th class="px-2 py-2 font-medium">Mémoire</th><th class="px-2 py-2 font-medium">Disque</th><th class="px-2 py-2 font-medium">Mises à jour</th><th class="px-2 py-2 font-medium">Ports publics</th><th class="px-2 py-2 pr-4 font-medium">À noter</th>
        </tr></thead><tbody>{rows}</tbody></table></div>
    </main></div>"""
    write("A-parc", "Elio · Parc", body)

def server_header(extra_cls=""):
    return f"""<div class="flex items-start justify-between gap-4 {extra_cls}">
      <div><div class="flex items-center gap-3"><h1 class="text-xl font-semibold">db-prod</h1>{status("crit")}
        <span class="rounded-full bg-subtle px-2 py-0.5 text-xs text-ink-2"><span class="mr-1 inline-block h-2 w-2 rounded-full bg-[#2a78d6]"></span>Production</span></div>
        <p class="mt-1 font-mono text-xs text-ink-3">admin@10.0.1.20:22 · Debian 12 · 8 vCPU · 32 Go · démarré il y a 41 j</p></div>
      <div class="flex gap-2">{btn("Actualiser l'inventaire", "refresh")}{btn("Modifier")}</div></div>"""

def health_cards():
    cpu = series(48, 55, 22, seed=3, trend=0.3)
    disk = [min(94, 78 + i * 0.34) for i in range(48)]
    return f"""<div class="grid grid-cols-3 gap-3">
      <div class="rounded-xl border border-line bg-surface px-4 py-3"><p class="text-xs text-ink-3">Charge CPU</p><div class="mt-1 flex items-end justify-between"><p class="whitespace-nowrap text-2xl font-semibold tabular-nums">1,9 <span class="text-sm font-normal text-ink-3">/ 8 cœurs</span></p>{spark(cpu[-20:], w=80, h=28)}</div></div>
      <div class="rounded-xl border border-line bg-surface px-4 py-3"><p class="text-xs text-ink-3">Mémoire</p><p class="mt-1 text-2xl font-semibold tabular-nums">88 % <span class="text-sm font-normal text-ink-3">28,1 / 32 Go</span></p><div class="mt-2">{meter(88, width="w-full", show_value=False)}</div></div>
      <div class="rounded-xl border border-crit/40 bg-surface px-4 py-3"><p class="flex items-center gap-1 text-xs text-crit-ink">{icon("x", "h-3.5 w-3.5")}Disque / · critique</p><p class="mt-1 text-2xl font-semibold tabular-nums text-crit-ink">94 % <span class="text-sm font-normal text-ink-3">451 / 480 Go</span></p><div class="mt-2">{meter(94, width="w-full", show_value=False)}</div></div>
    </div>""", disk

def a_server():
    tabs = "".join(f'<a class="flex items-center gap-1.5 border-b-2 px-1 pb-2.5 {"border-accent font-medium text-ink" if t == "Vue d’ensemble" else "border-transparent text-ink-3"}">{t}{tab_count(n)}</a>'
                   for t, n in [("Vue d’ensemble", None), ("Paquets", "1 284"), ("Services", "47"), ("Ports", "6"), ("Clés SSH", "5"), ("Historique", None)])
    hc, disk = health_cards()
    body = f"""<div class="flex h-screen">{a_sidebar("Parc")}
    <main class="min-w-0 flex-1 overflow-auto px-8 py-6">
      <p class="text-xs text-ink-3">Parc <span class="mx-1">/</span> Production <span class="mx-1">/</span> db-prod</p>
      <div class="mt-2">{server_header()}</div>
      <nav class="mt-5 flex gap-6 border-b border-line text-sm">{tabs}</nav>
      <div class="mt-5 grid grid-cols-3 gap-4">
        <div class="col-span-2 space-y-4">{hc}
          {card("Disque / — 24 h", chart(disk, warn=90, color="var(--color-crit)", w=700, h=150), '<span class="text-xs text-ink-3">+16 points en 24 h · plein dans ~3 jours</span>')}
          {card("Ports exposés", ports_table(), f'<a class="text-xs font-medium text-accent">Règles ufw suggérées →</a>')}
        </div>
        <div class="space-y-4">
          {card("À traiter", '<ul class="space-y-2 text-sm">' + "".join(f'<li class="flex gap-2"><span class="mt-0.5 text-{t}-ink">{icon(i, "h-4 w-4")}</span><span>{x}</span></li>' for t, i, x in [("crit", "x", "Disque / à 94 %"), ("crit", "alert", "6432/tcp public non filtré (pgbouncer)"), ("warn", "alert", "fail2ban en échec"), ("warn", "shield", "4 mises à jour de sécurité")]) + "</ul>")}
          {card("Système", kv(SYSTEM_ROWS))}
          {card("Historique", history_list())}
        </div>
      </div>
    </main></div>"""
    write("A-serveur", "Elio · db-prod", body)

# ================================================================ B — Cartes (grid + one-page sheet)
def b_topnav(active):
    links = "".join(f'<a class="rounded-lg px-3 py-1.5 {"bg-subtle font-medium text-ink" if l == active else "text-ink-2"}">{l}</a>' for l in ["Parc", "Trousseau", "Activité", "Automatisations"])
    return f"""<header class="border-b border-line bg-surface"><div class="mx-auto flex max-w-7xl items-center gap-6 px-6 py-3">{logo()}<nav class="flex gap-1">{links}</nav>
      <div class="ml-auto flex items-center gap-2 rounded-lg border border-line bg-canvas px-2.5 py-1.5 text-ink-3">{icon("search")}<span class="w-40">Rechercher…</span><kbd class="rounded border border-line px-1 text-[10px]">⌘K</kbd></div>
      {icon("cog", "h-5 w-5 text-ink-3")}<span class="grid h-8 w-8 place-items-center rounded-full bg-subtle text-xs font-semibold">AM</span></div></header>"""

def b_card(s, i):
    name, host, user, group, osn, st, load, ram, disk, upd, sec, ports, reason = s
    tone = STATE[st][1]
    border = {"good": "border-line", "warn": "border-warn/60", "crit": "border-crit/50"}[tone]
    if load is None:
        inner = f'<div class="mt-4 flex h-[74px] items-center justify-center rounded-lg bg-subtle text-xs text-ink-3">{icon("off", "mr-1.5 h-4 w-4")}Pas de réponse depuis 12 min</div>'
    else:
        inner = f'<div class="mt-4 space-y-2">{meter(min(99, load / 4 * 100), "CPU", "flex-1")}{meter(ram, "RAM", "flex-1")}{meter(disk, "Disque", "flex-1")}</div>'
    foot = f'<p class="mt-3 flex items-center gap-1.5 text-xs text-{tone}-ink">{icon(STATE[st][2], "h-3.5 w-3.5")}{reason}</p>' if reason else \
           f'<p class="mt-3 text-xs text-ink-3">{upd} mises à jour · ports {ports}</p>'
    return f"""<article class="rounded-xl border {border} bg-surface p-4">
      <div class="flex items-start justify-between"><div><p class="font-semibold">{name}</p><p class="text-xs text-ink-3">{os_label(osn)} · {group}</p></div>{status(st)}</div>
      {inner}{foot}</article>"""

def b_fleet():
    order = sorted(range(len(S)), key=lambda i: {"crit": 0, "down": 0, "warn": 1, "ok": 2}[S[i][5]])
    cards = "".join(b_card(S[i], i) for i in order)
    summary = "".join(f'<div class="flex items-center gap-2"><span class="text-2xl font-semibold tabular-nums text-{t}-ink">{n}</span><span class="text-xs leading-tight text-ink-3">{l}</span></div>'
                      for n, l, t in [(counts["ok"], "en ligne", "good"), (counts["warn"], "à surveiller", "warn"), (counts["crit"] + counts["down"], "critiques", "crit")])
    seg = "".join(f'<div class="h-2 rounded-full bg-{t}" style="flex:{n}"></div>' for n, t in [(counts["ok"], "good"), (counts["warn"], "warn"), (counts["crit"] + counts["down"], "crit")])
    body = f"""{b_topnav("Parc")}<main class="mx-auto max-w-7xl px-6 py-6">
      <div class="flex items-end justify-between"><div><h1 class="text-2xl font-semibold">Bonjour Alice</h1><p class="text-ink-3">3 serveurs demandent ton attention.</p></div>
        <div class="flex gap-2">{btn("Actualiser", "refresh")}{btn("Ajouter un serveur", "plus", True)}</div></div>
      <div class="mt-5 rounded-xl border border-line bg-surface px-5 py-4"><div class="flex items-center gap-8">{summary}<div class="ml-auto w-80"><div class="flex gap-0.5">{seg}</div><p class="mt-1.5 text-right text-xs text-ink-3">12 serveurs · 57 mises à jour de sécurité</p></div></div></div>
      <div class="mt-5 flex items-center gap-2">{"".join(f'<span class="rounded-full px-3 py-1 text-xs {"bg-ink text-canvas font-medium" if c == "Tous" else "border border-line bg-surface text-ink-2"}">{c}</span>' for c in ["Tous", "Production", "Infra", "Staging"])}
        <span class="ml-auto text-xs text-ink-3">Trier : les problèmes d'abord</span></div>
      <div class="mt-4 grid grid-cols-4 gap-4">{cards}</div></main>"""
    write("B-parc", "Elio · Parc", body)

def section(title, ic, body, right="", open_=True):
    chev = icon("down" if open_ else "chevron", "h-4 w-4 text-ink-3")
    content = f'<div class="border-t border-line px-5 py-4">{body}</div>' if open_ else ""
    return (f'<section class="rounded-xl border border-line bg-surface"><div class="flex items-center gap-2 px-5 py-3">{chev}{icon(ic, "h-4 w-4 text-ink-2")}'
            f'<h2 class="font-semibold">{title}</h2><div class="ml-auto text-xs text-ink-3">{right}</div></div>{content}</section>')

def b_server():
    hc, disk = health_cards()
    body = f"""{b_topnav("Parc")}<main class="mx-auto max-w-5xl px-6 py-6">
      <a class="text-xs text-ink-3">← Parc</a>
      <div class="mt-2">{server_header()}</div>
      <div class="mt-5 rounded-xl border border-crit/40 bg-crit-soft px-4 py-3 text-sm text-crit-ink"><p class="flex items-center gap-2 font-medium">{icon("x")}2 problèmes critiques</p>
        <p class="mt-1 pl-6 text-xs">Disque / à 94 % (plein dans ~3 jours) · Port 6432/tcp exposé sans règle firewall</p></div>
      <div class="mt-5 space-y-3">
        {section("Santé", "activity", hc + '<div class="mt-4">' + chart(disk, warn=90, color="var(--color-crit)", w=900, h=150) + "</div>", "relevé il y a 14 min")}
        {section("Système", "server", kv(SYSTEM_ROWS), "Debian 12")}
        {section("Ports", "plug", ports_table(), "6 en écoute · 3 publics")}
        {section("Services", "list", services_list(), "47 services · 1 en échec · 2 conteneurs")}
        {section("Paquets", "box", "", "1 284 installés · 12 mises à jour dont 4 sécurité", open_=False)}
        {section("Clés SSH", "key", "", "5 clés · 1 hors trousseau", open_=False)}
        {section("Historique", "clock", "", "dernier événement il y a 14 min", open_=False)}
      </div></main>"""
    write("B-serveur", "Elio · db-prod", body)

# ================================================================ C — Commande (search-first, split view)
def c_top():
    return f"""<header class="flex items-center gap-4 border-b border-line bg-surface px-5 py-2.5">{logo()}
      <div class="mx-auto flex w-[560px] items-center gap-2 rounded-xl border border-line bg-canvas px-3 py-2 text-ink-3 shadow-sm">{icon("search")}<span>Aller à un serveur, chercher un paquet, un port…</span><kbd class="ml-auto rounded border border-line px-1.5 text-[11px]">⌘K</kbd></div>
      <nav class="flex items-center gap-4 text-ink-2"><a class="font-medium text-ink">Parc</a><a>Trousseau</a><a>Activité</a>{icon("bolt", "h-4 w-4")}{icon("cog", "h-4 w-4")}</nav></header>"""

def c_list(selected):
    out = ""
    for s in sorted(S, key=lambda s: {"crit": 0, "down": 0, "warn": 1, "ok": 2}[s[5]]):
        name, host, user, group, osn, st, load, ram, disk, *_r, reason = s
        on = name == selected
        sub = reason or f"{osn} · disque {disk} %"
        out += (f'<a class="flex items-center gap-3 border-l-2 px-4 py-2.5 {"border-accent bg-accent-soft" if on else "border-transparent"}">{dot(st)}'
                f'<div class="min-w-0 flex-1"><p class="truncate font-medium">{name}</p><p class="truncate text-xs {"text-" + STATE[st][1] + "-ink" if reason else "text-ink-3"}">{sub}</p></div>'
                f'<span class="text-[11px] text-ink-3">{group}</span></a>')
    return out

def c_fleet():
    # overview: "inbox" of issues + group health + recent changes
    issues = [("crit", "x", "db-prod", "Disque / à 94 % — plein dans ~3 jours", "Voir le disque"),
              ("crit", "alert", "legacy-ftp", "MySQL (3306/tcp) exposé sur Internet", "Règle ufw"),
              ("crit", "off", "ci-runner", "Injoignable depuis 12 min", "Réessayer"),
              ("warn", "alert", "worker-1", "Redémarrage requis (noyau mis à jour)", "Détails"),
              ("warn", "clock", "backup", "Debian 11 : fin de support en août 2026", "Planifier"),
              ("warn", "shield", "7 serveurs", "57 mises à jour de sécurité disponibles", "Voir les paquets")]
    inbox = "".join(f'<li class="flex items-center gap-3 px-4 py-3"><span class="text-{t}-ink">{icon(i)}</span><div class="flex-1"><p><span class="font-medium">{who}</span> <span class="text-ink-2">— {what}</span></p></div>{btn(a)}</li>' for t, i, who, what, a in issues)
    groups = ""
    for g, total, ok, warn, crit in [("Production", 6, 4, 1, 1), ("Infra", 4, 2, 1, 1), ("Staging", 2, 1, 0, 1)]:
        seg = "".join(f'<div class="h-2 rounded-full bg-{t}" style="flex:{n}"></div>' for n, t in [(ok, "good"), (warn, "warn"), (crit, "crit")] if n)
        groups += f'<div class="py-2.5"><div class="flex justify-between text-sm"><span class="font-medium">{g}</span><span class="text-xs text-ink-3">{ok}/{total} sains</span></div><div class="mt-1.5 flex gap-0.5">{seg}</div></div>'
    changes = "".join(f'<li class="flex gap-3 py-2"><span class="w-16 shrink-0 text-xs text-ink-3">{w}</span><span>{t}</span></li>' for w, t in
                      [("14:02", "db-prod : disque passé au-dessus de 90 %"), ("13:40", "worker-1 : linux-image mis à jour (6.1.115)"), ("11:15", "staging : port 8080/tcp ouvert"), ("09:30", "Clé « Bastien Roy » ajoutée sur db-prod pour 24 h")])
    body = f"""{c_top()}<main class="mx-auto grid max-w-7xl grid-cols-3 gap-5 px-6 py-6">
      <div class="col-span-2"><div class="flex items-baseline justify-between"><h1 class="text-xl font-semibold">À traiter</h1><span class="text-xs text-ink-3">6 éléments · trié par gravité</span></div>
        <ul class="mt-3 divide-y divide-line rounded-xl border border-line bg-surface">{inbox}</ul>
        <h2 class="mt-6 font-semibold">Changements du jour</h2><ul class="mt-2 rounded-xl border border-line bg-surface px-4 py-1">{changes}</ul></div>
      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-3">{stat_tile("En ligne", f'{counts["ok"]}/12', "serveurs sains", "good", "check")}{stat_tile("Problèmes", counts["warn"] + counts["crit"] + counts["down"], "dont 3 critiques", "crit", "alert")}</div>
        {card("Santé par groupe", groups)}
        {card("Systèmes", kv([("Ubuntu 24.04 LTS", "5"), ("Ubuntu 22.04 LTS", "3"), ("Debian 12", "3"), ('<span class="text-warn-ink">Debian 11</span>', "1"), ('<span class="text-crit-ink">Debian 10 · plus supporté</span>', "1")]))}
      </div></main>"""
    write("C-parc", "Elio · À traiter", body)

def c_server():
    hc, disk = health_cards()
    tabs = "".join(f'<a class="rounded-lg px-2.5 py-1 {"bg-subtle font-medium" if t == "Ports" else "text-ink-3"}">{t}</a>' for t in ["Résumé", "Santé", "Paquets", "Services", "Ports", "Clés", "Historique"])
    ufw = "\n".join(["sudo ufw default deny incoming", "sudo ufw allow 22/tcp comment 'ssh'", "# 6432/tcp : publié par Docker (pgbouncer),", "# ufw ne le filtre pas → lier à 10.0.1.20", "sudo ufw allow from 10.0.0.0/16 to any port 9100 proto tcp", "sudo ufw enable"])
    body = f"""{c_top()}<div class="flex" style="height:calc(100vh - 57px)">
      <aside class="w-80 shrink-0 overflow-auto border-r border-line bg-surface"><div class="flex items-center justify-between px-4 py-3"><p class="font-semibold">Parc <span class="font-normal text-ink-3">12</span></p><span class="text-xs text-ink-3">Problèmes d'abord</span></div>{c_list("db-prod")}</aside>
      <main class="min-w-0 flex-1 overflow-auto px-8 py-5">{server_header()}
        <nav class="mt-4 flex gap-1 text-sm">{tabs}</nav>
        <div class="mt-4 grid grid-cols-3 gap-4"><div class="col-span-2">{card("Ports en écoute", ports_table(), '<span class="text-xs text-ink-3">firewall : ufw actif</span>')}</div>
          <div>{card("Règles ufw suggérées", f'<pre class="whitespace-pre-wrap break-all rounded-lg bg-subtle p-3 font-mono text-[11px] leading-relaxed text-ink-2">{ufw}</pre><p class="mt-2 text-xs text-ink-3">Elio ne modifie jamais le firewall : copiez et appliquez vous-même.</p>', f'<span class="inline-flex items-center gap-1 text-xs text-accent">{icon("copy", "h-3.5 w-3.5")}Copier</span>')}</div></div>
        <div class="mt-4 grid grid-cols-2 gap-4">{card("Services liés", services_list())}{card("Clés SSH", keys_list())}</div>
      </main></div>"""
    write("C-serveur", "Elio · db-prod", body)

# ================================================================ mobile (one per direction, fleet)
def mobile(name, head, rows_html):
    body = f'<div class="min-h-screen w-[390px] border-r border-line">{head}{rows_html}</div>'
    write(name, "Elio · mobile", body)

def m_rows(style):
    out = ""
    for s in sorted(S, key=lambda s: {"crit": 0, "down": 0, "warn": 1, "ok": 2}[s[5]])[:8]:
        name, host, user, group, osn, st, load, ram, disk, *_r, reason = s
        if style == "B":
            out += f'<div class="mx-4 mb-3">{b_card(s, 0)}</div>'
        else:
            out += (f'<div class="flex items-center gap-3 border-b border-line bg-surface px-4 py-3">{dot(st)}<div class="min-w-0 flex-1"><p class="font-medium">{name}</p>'
                    f'<p class="truncate text-xs {"text-" + STATE[st][1] + "-ink" if reason else "text-ink-3"}">{reason or osn}</p></div>'
                    f'{meter(disk, width="w-12") if disk is not None else ""}{icon("chevron", "h-4 w-4 text-ink-3")}</div>')
    return out

def m_head(title):
    return (f'<div class="flex items-center justify-between border-b border-line bg-surface px-4 py-3">{logo()}<div class="flex gap-3 text-ink-2">{icon("search", "h-5 w-5")}<span class="grid h-7 w-7 place-items-center rounded-full bg-subtle text-[11px] font-semibold">AM</span></div></div>'
            f'<div class="px-4 py-3"><h1 class="text-lg font-semibold">{title}</h1><div class="mt-2 flex gap-2 text-xs">'
            f'<span class="rounded-full bg-good-soft px-2 py-0.5 text-good-ink">{counts["ok"]} en ligne</span><span class="rounded-full bg-warn-soft px-2 py-0.5 text-warn-ink">{counts["warn"]} à surveiller</span><span class="rounded-full bg-crit-soft px-2 py-0.5 text-crit-ink">{counts["crit"] + counts["down"]} critiques</span></div></div>')

a_fleet(); a_server(); b_fleet(); b_server(); c_fleet(); c_server()
mobile("A-mobile", m_head("Parc"), m_rows("A"))
mobile("B-mobile", m_head("Parc"), m_rows("B"))
mobile("C-mobile", m_head("À traiter"), m_rows("C"))
print("ok")
