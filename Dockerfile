FROM centos:7

RUN yum install -y epel-release && yum -y update && yum -y install nodejs npm

ENV HOME /var/lib/documara
RUN useradd --home-dir $HOME documara

WORKDIR $HOME

# Install node modules:
ADD package.json ./
RUN /usr/bin/chown --recursive documara:documara $HOME
RUN yum install -y make && su -c 'npm install' documara && yum remove -y make


ADD assets static *.coffee *.js  ./
RUN /usr/bin/chown --recursive documara:documara $HOME

USER documara

ENV NODE_ENV development
ENV SESSION_SECRET insecure

EXPOSE 8080

# REDIS_PORT and REDIS_HOST can't use ENV because they're set via `--link` which
# happens when the container is started, not built.
CMD REDIS_PORT=$REDIS_PORT_6379_TCP_PORT \
    REDIS_HOST=$REDIS_PORT_6379_TCP_ADDR \
    node_modules/coffee-script/bin/coffee appserver.coffee