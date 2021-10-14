FROM registry.access.redhat.com/ubi8/php-73:latest

#Provide required information to dockerfile
ARG PKG_L=https://releases.wikimedia.org/mediawiki/1.36/mediawiki-1.36.2.tar.gz
ARG PKG=mediawiki-1.36.2

USER root

RUN wget $PKG_L
RUN wget $PKG_L.sig 

WORKDIR /var/www
RUN tar -zxf $HOME/$PKG.tar.gz
RUN ln -s $PKG/ mediawiki

WORKDIR /var/www
RUN sed -i 's/Listen 0.0.0.0:8080/Listen 0.0.0.0:80/g' /etc/httpd/conf/httpd.conf \
    && sed -i 's/Listen 0.0.0.0:8443/#Listen 0.0.0.0:8443/g' /etc/httpd/conf.d/ssl.conf \
    && sed -i 's/DirectoryIndex index.html/DirectoryIndex index.html index.html.var index.php/g' /etc/httpd/conf/httpd.conf \
    && ln -s $PKG/ mediawiki \
    && chown -R apache:apache /var/www/$PKG \
    && chown -R apache:apache /var/www/mediawiki

EXPOSE 80
USER root
ENTRYPOINT httpd -f /etc/httpd/conf/httpd.conf -D FOREGROUND 
