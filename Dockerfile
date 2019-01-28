FROM alpine:3.8

RUN apk --update --no-cache add exim bash

ADD exim/ /etc/exim/
ADD run.sh /run.sh

VOLUME /var/spool/exim

CMD ["/run.sh"]
