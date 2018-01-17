FROM alpine:3.7

RUN apk --update --no-cache add exim bash

ADD exim.conf /etc/exim/exim.conf
ADD run.sh /run.sh
RUN chmod 0755 /run.sh

VOLUME /var/spool/exim

CMD ["/run.sh"]
