FROM centos:7

RUN yum install -y epel-release && yum -y update && yum -y install nodejs npm

ENV HOME /var/lib/documara
RUN useradd --home-dir $HOME documara

WORKDIR /var/lib/documara

ADD assets assets
ADD static static
ADD package.json package.json

RUN /usr/bin/chown --recursive documara:documara $HOME

#USER documara

ENV NODE_ENV development
ENV SESSION_SECRET=insecure

EXPOSE 8080
