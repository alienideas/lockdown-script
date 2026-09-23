#Requires -RunAsAdministrator
# Final-Lockdown-Keep-DoH.ps1
# Windows 10/11 – Outbound lockdown + hosts ad blocking (DoH left enabled)

$ErrorActionPreference = "Stop"
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupHosts = "$hostsPath.bak_$timestamp"
$logFile = "$env:TEMP\LockdownLog_$timestamp.txt"

function Write-Log($msg) {
    $line = "$(Get-Date -Format 'HH:mm:ss')  $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Write-Log "=== STARTING LOCKDOWN (DoH kept enabled) ==="

# -------------------------------------------------
# 1. Backup hosts file
# -------------------------------------------------
Copy-Item $hostsPath $backupHosts -Force
Write-Log "Hosts backup created: $backupHosts"

# -------------------------------------------------
# 2. Add ~100 high-value ad / tracking domains
# -------------------------------------------------
Write-Log "Adding ad/tracking domains to hosts file..."

$adDomains = @(
    # Google
    "doubleclick.net", "www.doubleclick.net", "ad.doubleclick.net", "googleads.g.doubleclick.net",
    "pagead2.googlesyndication.com", "googlesyndication.com", "googleadservices.com",
    "adservice.google.com", "ads.google.com", "google-analytics.com", "ssl.google-analytics.com",
    "www.google-analytics.com", "googletagmanager.com", "www.googletagmanager.com",
    "googletagservices.com", "2mdn.net", "pagead.l.doubleclick.net",

    # Facebook / Meta
    "facebook.com", "www.facebook.com", "connect.facebook.net", "pixel.facebook.com",
    "an.facebook.com", "ads.facebook.com", "graph.facebook.com",

    # Amazon
    "amazon-adsystem.com", "aax.amazon-adsystem.com", "aax-us-east.amazon-adsystem.com",
    "fls-na.amazon-adsystem.com", "ir-na.amazon-adsystem.com",

    # Major ad networks / SSPs
    "adnxs.com", "ib.adnxs.com", "secure.adnxs.com",
    "criteo.com", "static.criteo.net", "bidder.criteo.com",
    "pubmatic.com", "ads.pubmatic.com",
    "openx.net", "openx.com",
    "rubiconproject.com", "ads.rubiconproject.com",
    "indexexchange.com", "casalemedia.com",
    "smartadserver.com", "lijit.com", "sovrn.com",
    "contextweb.com", "bidswitch.net", "adform.net", "adformdsp.net",
    "adsrvr.org", "advertising.com", "adtech.com", "adtechus.com",
    "yieldmo.com", "sharethrough.com", "triplelift.com", "3lift.com",
    "teads.tv", "outbrain.com", "taboola.com", "trc.taboola.com",
    "mgid.com", "revcontent.com", "zemanta.com",

    # Mobile / In-app
    "applovin.com", "unity3d.com", "ironsrc.com", "vungle.com",
    "chartboost.com", "inmobi.com", "mintegral.com", "liftoff.io",
    "mopub.com", "adcolony.com", "tapjoy.com", "fyber.com",

    # Analytics / Trackers
    "scorecardresearch.com", "quantserve.com", "quantcast.com",
    "hotjar.com", "clarity.ms", "mouseflow.com", "fullstory.com",
    "segment.com", "segment.io", "mixpanel.com", "amplitude.com",
    "appsflyer.com", "adjust.com", "branch.io", "kochava.com",
    "crashlytics.com", "sentry.io", "newrelic.com", "datadoghq.com",
    "moatads.com", "moat.com", "doubleverify.com",
    "comscore.com", "nielsen.com", "krxd.net", "bluekai.com",
    "exelator.com", "rlcdn.com", "demdex.net", "omtrdc.net",
    "2o7.net", "omappapi.com", "crazyegg.com",

    # Other common ad domains
    "adsafeprotected.com", "adsymptotic.com", "mathtag.com",
    "media.net", "media6degrees.com", "serving-sys.com",
    "eyeota.net", "lotame.com", "crwdcntrl.net", "turn.com",
    "sitescout.com", "bidr.io", "spotxchange.com", "spotx.tv",
    "smartclip.net", "stickyadstv.com", "teads.com",
    "yieldlab.net", "adition.com", "adscale.de", "adzerk.net",
    "appnexus.com"
)

# Remove previous lockdown section if script is re-run
$currentHosts = Get-Content $hostsPath -Raw -ErrorAction SilentlyContinue
if ($currentHosts -match "# === LOCKDOWN AD BLOCK START ===") {
    $cleaned = $currentHosts -replace "(?s)# === LOCKDOWN AD BLOCK START ===.*?# === LOCKDOWN AD BLOCK END ===\r?\n?", ""
    Set-Content -Path $hostsPath -Value $cleaned -Force
}

$entries = @()
$entries += ""
$entries += "# === LOCKDOWN AD BLOCK START ===  (added $timestamp)"
$entries += "# ~100 major ad / tracking / analytics domains"

foreach ($d in ($adDomains | Sort-Object -Unique)) {
    $entries += "0.0.0.0`t$d"
}

$entries += "# === LOCKDOWN AD BLOCK END ==="
$entries += ""

Add-Content -Path $hostsPath -Value $entries
Write-Log "Added $($adDomains.Count) domains to hosts file."

# -------------------------------------------------
# 3. Flush DNS
# -------------------------------------------------
ipconfig /flushdns | Out-Null
Clear-DnsClientCache -ErrorAction SilentlyContinue
Write-Log "DNS cache flushed."

# -------------------------------------------------
# 4. Windows Firewall – hard outbound lockdown
# -------------------------------------------------
Write-Log "Configuring Windows Firewall (Outbound = Block by default)..."

# Remove previous rules from this script
Get-NetFirewallRule -DisplayName "Lockdown-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule

# Default outbound = Block
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Block
Write-Log "Default Outbound Action = Block (all profiles)."

# Allow DNS
New-NetFirewallRule -DisplayName "Lockdown-Allow-DNS-UDP" `
    -Direction Outbound -Action Allow -Protocol UDP -RemotePort 53 `
    -Profile Any -Enabled True | Out-Null

New-NetFirewallRule -DisplayName "Lockdown-Allow-DNS-TCP" `
    -Direction Outbound -Action Allow -Protocol TCP -RemotePort 53 `
    -Profile Any -Enabled True | Out-Null

# Allow web
New-NetFirewallRule -DisplayName "Lockdown-Allow-HTTP" `
    -Direction Outbound -Action Allow -Protocol TCP -RemotePort 80 `
    -Profile Any -Enabled True | Out-Null

New-NetFirewallRule -DisplayName "Lockdown-Allow-HTTPS" `
    -Direction Outbound -Action Allow -Protocol TCP -RemotePort 443 `
    -Profile Any -Enabled True | Out-Null

# Allow email ports you requested
New-NetFirewallRule -DisplayName "Lockdown-Allow-SMTP-587" `
    -Direction Outbound -Action Allow -Protocol TCP -RemotePort 587 `
    -Profile Any -Enabled True | Out-Null

New-NetFirewallRule -DisplayName "Lockdown-Allow-POP3S-995" `
    -Direction Outbound -Action Allow -Protocol TCP -RemotePort 995 `
    -Profile Any -Enabled True | Out-Null

# Allow ICMP
New-NetFirewallRule -DisplayName "Lockdown-Allow-ICMPv4" `
    -Direction Outbound -Action Allow -Protocol ICMPv4 `
    -Profile Any -Enabled True | Out-Null

# Block QUIC (HTTP/3)
New-NetFirewallRule -DisplayName "Lockdown-Block-QUIC-UDP443" `
    -Direction Outbound -Action Block -Protocol UDP -RemotePort 443 `
    -Profile Any -Enabled True | Out-Null

# Block DNS-over-TLS
New-NetFirewallRule -DisplayName "Lockdown-Block-DoT-853" `
    -Direction Outbound -Action Block -Protocol TCP -RemotePort 853 `
    -Profile Any -Enabled True | Out-Null

New-NetFirewallRule -DisplayName "Lockdown-Block-DoT-UDP853" `
    -Direction Outbound -Action Block -Protocol UDP -RemotePort 853 `
    -Profile Any -Enabled True | Out-Null

Write-Log "Firewall rules applied."

# -------------------------------------------------
# 5. Final status
# -------------------------------------------------
Write-Log ""
Write-Log "=== LOCKDOWN COMPLETE (DoH left enabled) ==="
Write-Log "Hosts file: $hostsPath"
Write-Log "Backup:     $backupHosts"
Write-Log "Log:        $logFile"
Write-Log ""
Write-Log "ALLOWED outbound:"
Write-Log "  • TCP 80 / 443   (web)"
Write-Log "  • TCP 587 / 995  (email)"
Write-Log "  • UDP/TCP 53     (DNS)"
Write-Log "  • ICMPv4"
Write-Log ""
Write-Log "BLOCKED:"
Write-Log "  • All other outbound ports"
Write-Log "  • UDP 443 (QUIC)"
Write-Log "  • TCP/UDP 853 (DoT)"
Write-Log "  • ~100 major ad/tracking domains via hosts file"
Write-Log ""
Write-Log "IMPORTANT – Browser Secure DNS still bypasses hosts file!"
Write-Log "Turn it OFF in every browser:"
Write-Log "  Chrome/Edge → Settings → Privacy → Security → Use secure DNS → Off"
Write-Log "  Firefox     → Settings → Privacy → DNS over HTTPS → Off"
Write-Log ""
Write-Log "TO RESTORE LATER:"
Write-Log "  Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Allow"
Write-Log "  Copy-Item '$backupHosts' '$hostsPath' -Force"
Write-Log "  ipconfig /flushdns"
Write-Log ""
Write-Log "Script finished successfully."