# Dockerfile for latest Nagios.
FROM ubuntu:20.04

ENV NAGIOS_VERSION=4.4.7
ENV NAGIOS_PLUGINS_VERSION=2.3.3
ENV NAGIOS_GRAPH_VERSION=1.5.2
ENV CHECK_MYSQL_HEALTH_VERSION=2.2.2
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt install -y build-essential curl wget unzip iputils-ping apache2-utils libcgi-pm-perl librrds-perl libgd-gd2-perl libnagios-object-perl libdbi-perl libdbd-mysql-perl libssl-dev mailutils nginx fcgiwrap php-fpm openssh-client jq && \
# Install Nagios Core (--disable-ssl is workaround for seg fault error in nagios 4.4.7)
    adduser --system --group --force-badname nagios && \
    usermod -a -G nagios www-data && \
    wget https://github.com/NagiosEnterprises/nagioscore/archive/nagios-${NAGIOS_VERSION}.tar.gz && \
    tar xzf nagios-${NAGIOS_VERSION}.tar.gz && \
    cd nagioscore-nagios-${NAGIOS_VERSION} && \
    ./configure \
        --disable-ssl \
        --with-nagios-user=nagios \
        --with-nagios-group=nagios \
        --with-command-group=nagios && \
    make all && \
    make install && \
    make install-config && \
    make clean && \
    mkdir -p /var/spool/nagios/checkresults && \
    chown nagios:nagios /var/spool/nagios/checkresults && \
    mkdir -p /usr/rw/nagios && \
    chown nagios:nagios /usr/rw/nagios && \
# Install Nagios Plugins
    cd / && \
    wget http://nagios-plugins.org/download/nagios-plugins-${NAGIOS_PLUGINS_VERSION}.tar.gz && \
    tar xzf nagios-plugins-${NAGIOS_PLUGINS_VERSION}.tar.gz && \
    cd nagios-plugins-${NAGIOS_PLUGINS_VERSION} && \
    ./configure \
        --with-nagios-user=nagios \
        --with-nagios-group=nagios && \
    make && \
    make install && \
    make clean && \
# Install Nagiosgraph
    cd / && \
    wget https://downloads.sourceforge.net/project/nagiosgraph/nagiosgraph/${NAGIOS_GRAPH_VERSION}/nagiosgraph-${NAGIOS_GRAPH_VERSION}.tar.gz && \
    tar xvf nagiosgraph-${NAGIOS_GRAPH_VERSION}.tar.gz && \
    cd nagiosgraph-${NAGIOS_GRAPH_VERSION} && \
    ./install.pl \
        --prefix /usr/local/nagiosgraph \
        --nagios-user nagios \
        --www-user www-data \
        --nagios-perfdata-file /usr/local/nagios/var/perfdata.log \
        --nagios-cgi-url /cgi-bin || true && \
    cp share/nagiosgraph.ssi /usr/local/nagios/share/ssi/common-header.ssi && \
# Install Mysql health check plugin
    cd / && \
    wget https://labs.consol.de/assets/downloads/nagios/check_mysql_health-${CHECK_MYSQL_HEALTH_VERSION}.tar.gz && \
    tar xvf check_mysql_health-${CHECK_MYSQL_HEALTH_VERSION}.tar.gz && \
    cd check_mysql_health-${CHECK_MYSQL_HEALTH_VERSION} && \
    ./configure \
        --with-nagios-user=nagios \
        --with-nagios-group=nagios && \
    make && \
    make install && \
    mkdir -p /usr/local/nagios/plugins && \
    cp plugins-scripts/check_mysql_health /usr/local/nagios/plugins/check_mysql_health && \
    make clean && \
# Cleanup
    cd / && \
    rm -r nagios-${NAGIOS_VERSION}.tar.gz nagioscore-nagios-${NAGIOS_VERSION} nagios-plugins-${NAGIOS_PLUGINS_VERSION}.tar.gz nagios-plugins-${NAGIOS_PLUGINS_VERSION} nagiosgraph-${NAGIOS_GRAPH_VERSION}.tar.gz nagiosgraph-${NAGIOS_GRAPH_VERSION} check_mysql_health-${CHECK_MYSQL_HEALTH_VERSION}.tar.gz check_mysql_health-${CHECK_MYSQL_HEALTH_VERSION} && \
    apt-get -y remove --purge build-essential && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

COPY nginx/ /etc/nginx/
COPY etc/ /usr/local/nagios/etc/

WORKDIR /usr/local/nagios

COPY run.sh /run.sh
CMD ["/run.sh"]
