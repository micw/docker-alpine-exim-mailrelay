#!/bin/bash

set -e

if [ -z "${MAIL_HOSTNAME}" ]; then
  echo "MAIL_HOSTNAME not set - tyring to fetch from rancher metadata service"
  MAIL_HOSTNAME=$( wget -O- -q http://rancher-metadata/latest/self/host/name )
fi

echo "Using ${MAIL_HOSTNAME} as mail hostname"

sed -i "s/^primary_hostname = .*/primary_hostname = ${MAIL_HOSTNAME}/" /etc/exim/exim.conf

chown -R exim.exim /var/spool/exim
touch /var/log/exim/mainlog /var/log/exim/rejectlog /var/log/exim/paniclog
chown -R exim.exim /var/log/exim

tail -q -n 0 -f /var/log/exim/* &

exim -bdf -q15m -oX
