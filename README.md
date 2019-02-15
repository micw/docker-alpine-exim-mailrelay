Exim based mail relay image.

# Direct relaying

<aside class="warning">
	If your sender domain(s) uses SPF and/or DMARC, prefer smarthost relaying over direct relaying
</aside>

Ensure to set the MAIL_HOSTNAME variable to the name of the host where the
image runs on and setup DNS and rDNS correctly. On rancher, the hostname is
detected automatically.

# Smarthost relaying

Set MAIL_HOSTNAME and SMARTHOST (and optionally SMARTHOST_PORT) environment variables to enable relaying via smarthost.

TLS is automatically enforced for smarthost connections (can be disabled with SMARTHOST_TLS=false).

## Enable smarthost authentication

Set SMARTHOST_USERNAME and SMARTHOST_PASSWORD environment variables to authenticate against the smarthost.
