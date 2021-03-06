FROM containerstack/alpine-arm:3.5.2
MAINTAINER Remon Lam [remon@containerstack.io]

ENV IMAGE alpine
ENV PATH /opt/pihole:${PATH}

COPY install.sh /usr/local/bin/docker-install.sh
ENV setupVars /etc/pihole/setupVars.conf
ENV PIHOLE_INSTALL /tmp/ph_install.sh
ENV S6OVERLAY_RELEASE https://github.com/just-containers/s6-overlay/releases/download/v1.19.1.1/s6-overlay-armhf.tar.gz

RUN apk update
RUN apk upgrade --update && \
    apk add --no-cache bind-tools wget curl bash libcap

RUN curl -L -s $S6OVERLAY_RELEASE | tar xvzf - -C / && \
    docker-install.sh && \
    rm -rf /var/cache/apk/*

ADD s6/alpine-root /
COPY s6/service /usr/local/bin/service

# Things installer did and fix alpine+nginx differences
ENV WEBLOGDIR /var/log/nginx
ENV PHP_CONFIG '/etc/php5/php-fpm.conf'
RUN mkdir -p /etc/pihole/ && \
    mkdir -p /var/www/html/pihole && \
    mkdir -p /var/www/html/admin/ && \
    chown nginx:nginx /var/www/html && \
    touch ${WEBLOGDIR}/access.log ${WEBLOGDIR}/error.log && \
    chown -R nginx:nginx ${WEBLOGDIR} && \
    sed -i 's|^user\s*=.*$|user = nginx|' $PHP_CONFIG && \
    sed -i '/^;pid/ s|^;||' $PHP_CONFIG && \
    chmod 775 /var/www/html && \
    touch /var/log/pihole.log && \
    chmod 644 /var/log/pihole.log && \
    chown dnsmasq:root /var/log/pihole.log && \
    sed -i "s/@INT@/eth0/" /etc/dnsmasq.d/01-pihole.conf && \
    setcap CAP_NET_BIND_SERVICE=+eip `which dnsmasq` && \
    cp -f /usr/bin/list.sh /opt/pihole/list.sh && \
    echo 'Done!'

# php config start passes special ENVs into
ENV PHP_ENV_CONFIG '/etc/php5/fpm.d/envs.conf'
ENV PHP_ERROR_LOG '/var/log/nginx/error.log'
COPY ./start.sh /
COPY ./bash_functions.sh /

# IPv6 disable flag for networks/devices that do not support it
ENV IPv6 True

EXPOSE 53 53/udp
EXPOSE 80

ENV S6_LOGGING 0
ENV S6_KEEP_ENV 1
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS 2

SHELL ["/bin/sh", "-c"]
ENTRYPOINT [ "/init" ]
