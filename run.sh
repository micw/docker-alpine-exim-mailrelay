#!/bin/bash

set -e

check_dns() {
  echo "Resolving mail hostname"
  RESOLVED=$( nslookup ${MAIL_HOSTNAME} 2>/dev/null )
  if [ "$?" -ne "0" ]; then
    echo "WARNING! ${MAIL_HOSTNAME} cannot be resolved via DNS"
    return
  fi
  echo "Getting my own outbound IP address via api.ipify.org"
  MYIP=$( wget -O- -q 'https://api.ipify.org?format=text' 2>/dev/null) 
  if [ "$?" -ne "0" ]; then
    echo "WARNING! Unable to get my own IP address. Cannot verify if we use the right outbound IP for ${MAIL_HOSTNAME}"
  fi
  FOUND_MY_IP=0
  while read line; do
    linedata=(${line})
    if [ "${linedata[0]}" != "Address" ]; then
      continue
    fi
    if [ "${linedata[3]}" == "${MAIL_HOSTNAME}" ]; then
      echo "OK: ${MAIL_HOSTNAME} resolves to ${linedata[2]} which resolves back to ${linedata[3]}"
    else
      echo "WARNING! ${MAIL_HOSTNAME} resolves to ${linedata[2]} which resolves back to ${linedata[3]}. This should be fixed.".
    fi
    if [ "${linedata[2]}" == "${MYIP}" ]; then
      echo "OK: ${MAIL_HOSTNAME} resolves correctly to my outbound ip address."
      FOUND_MY_IP=1
    fi
  done <<<"$RESOLVED"
  if [ ! -z "${MYIP}" -a "${FOUND_MY_IP}" -eq 0 ]; then
    echo "WARNING! ${MAIL_HOSTNAME} does not resolve to my oputbound ip address ${MYIP}. This should be fixed."
  fi
}

if [ -z "${MAIL_HOSTNAME}" ]; then
  echo "MAIL_HOSTNAME not set - tyring to fetch from rancher metadata service ... "
  set +e
  MAIL_HOSTNAME=$( wget -O- -q http://rancher-metadata/latest/self/host/name )
  RC=$?
  set -e
  if [ "$RC" -ne "0" ]; then
    echo "Not running on rancher. Please set MAIL_HOSTNAME."
    exit 1
  fi
fi

echo "Using ${MAIL_HOSTNAME} as mail hostname"

sed -i "s/^primary_hostname = .*/primary_hostname = ${MAIL_HOSTNAME}/" /etc/exim/exim.conf

if [ -z "${SMARTHOST}" ]; then
  # No smarthost -> check that DNS works properly
  set +e
  check_dns
  set -e
else
	echo "Relaying via ${SMARTHOST}"
	cat << EOF > /etc/exim/routers.conf
smarthost:
  driver = manualroute
  domains = *
  transport = remote_smtp
  route_data = ${SMARTHOST}::${SMARTHOST_PORT:-25}
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
mkdir -p /var/log/exim
touch /var/log/exim/mainlog /var/log/exim/rejectlog /var/log/exim/paniclog
chown -R exim.exim /var/log/exim

if [ "${TAIL_LOGS:-true}" != "false" ]; then
    tail -q -n 0 -f /var/log/exim/* &
fi

exec exim -bdf -q15m -oX 25
