FROM debian:stable

RUN set -eux ; \
    apt-get -q update ; \
    DEBIAN_FRONTEND=noninteractive apt-get -qy install ruby

RUN gem install gitlab-triage
