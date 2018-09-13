#!/bin/bash

set -e

if [ -z "${MAIL_HOSTNAME}" ]; then
  echo "MAIL_HOSTNAME not set - tyring to fetch from rancher metadata service"
  MAIL_HOSTNAME=$( wget -O- -q http://rancher-metadata/latest/self/host/name )
fi

echo "Using ${MAIL_HOSTNAME} as mail hostname"

sed -i "s/^primary_hostname = .*/primary_hostname = ${MAIL_HOSTNAME}/" /etc/exim/exim.conf

if [ ! -z "${SMARTHOST}" ]; then
	echo "Relaying via ${SMARTHOST}"
	cat << EOF > /etc/exim/routers.conf
smarthost:
  driver = manualroute
  domains = *
  transport = remote_smtp
  route_data = ${SMARTHOST}
  no_more
EOF
	if [ "${SMARTHOST_TLS:-true}" != "false" ]; then
		echo "Enforcing TLS for smtp connections to smarthost"
		echo "  hosts_require_tls = ${SMARTHOST}" >> /etc/exim/transports.conf
	fi

	if [ ! -z "${SMARTHOST_USERNAME}" -a ! -z "${SMARTHOST_PASSWORD}" ]; then
		echo "Authentication to smarthost as ${SMARTHOST_USERNAME}"
		echo "  hosts_require_auth = ${SMARTHOST}" >> /etc/exim/transports.conf

		cat << EOF > /etc/exim/authenticators.conf
smarthost_auth_login:
  driver = plaintext
  public_name = LOGIN
  hide client_send = : ${SMARTHOST_USERNAME} : ${SMARTHOST_PASSWORD}
EOF
	fi
fi

chown -R exim.exim /var/spool/exim
touch /var/log/exim/mainlog /var/log/exim/rejectlog /var/log/exim/paniclog
chown -R exim.exim /var/log/exim

tail -q -n 0 -f /var/log/exim/* &

exim -bdf -q15m -oX
