FROM registry.opensuse.org/yast/sle-15/sp2/containers/yast-ruby
RUN zypper --non-interactive in --force-resolution --no-recommends \
  yast2-cluster
COPY . /usr/src/app
