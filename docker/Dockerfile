FROM ruby:2.5.0-alpine
MAINTAINER Firmhouse "kinnalru@gmail.com"

WORKDIR /home/app

RUN mkdir -p ~/.ssh && echo -e "Host * \
  \n  StrictHostKeyChecking no \
  \n  UserKnownHostsFile=/dev/null\n" >> ~/.ssh/config

RUN set -ex \
  && apk add --no-cache \
    bash \
    libstdc++ \
    libxml2 \
    ruby-libs \
    wget \
    curl \
    libcurl \
    ruby \
    git \
    tzdata 
    
RUN set -ex \
  && curl -sSLo /tmp/consul.zip https://releases.hashicorp.com/consul/1.2.1/consul_1.2.1_linux_amd64.zip \
  && unzip -d /bin /tmp/consul.zip \
  && rm -rf /tmp/consul.zip \
  && addgroup consul \
  && adduser -D -g "" -s /bin/sh -G consul consul \
  && mkdir -p /tmp/consul \
  && chown -R consul:consul /tmp/consul

RUN set -ex \
  && curl -so envconsul.tgz https://releases.hashicorp.com/envconsul/0.7.3/envconsul_0.7.3_linux_amd64.tgz \
  && tar -xvzf envconsul.tgz \
  && rm -rf envconsul.tgz \
  && mv envconsul /bin/envconsul \
  && chmod +x /bin/envconsul

ADD Gemfile Gemfile.lock docker_tools.gemspec /home/app/
ADD lib/ /home/app/lib

RUN set -ex \
  && bundle install \
  && cd / \
  && rm -rf /usr/src/ruby
  
ADD . /home/app



SHELL ["/bin/sh", "-c", "-l"]


