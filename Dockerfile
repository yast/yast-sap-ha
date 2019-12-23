FROM registry.opensuse.org/yast/head/containers/yast-ruby:latest
RUN zypper --non-interactive in --force-resolution --no-recommends \
  yast2-cluster
COPY . /usr/src/app
