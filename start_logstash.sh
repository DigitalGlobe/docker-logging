#!/bin/bash
set -e

# Setup logstash config based on environment variables set via
# Docker. Note that logstash config files cannot parse environment
# variables.

# Note the Perl Regex tricks: 
# (?<=foo) positive lookbehind
# (?=foo) positive lookahead
# test with `grep -Po PATTERN`
# http://unix.stackexchange.com/a/103008/94258
perl -pi -e "s|(?<=hosts => \\[\")(.*)(?=\"\\])|${ELASTICSEARCH_HOST}|g" /etc/logstash/conf.d/gelf_to_elasticsearch.conf
perl -pi -e "s|(?<=index => \")(.*)(?=-logs\-%{\+YYYY\.MM\.DD}\")|${ENVIRONMENT}|g" /etc/logstash/conf.d/gelf_to_elasticsearch.conf
perl -pi -e "s|(?<=region => \")(.*)(?=\")|${AWS_REGION}|g" /etc/logstash/conf.d/gelf_to_elasticsearch.conf

# Run as user logstash
set -- gosu logstash
logstash -f /etc/logstash/conf.d/gelf_to_elasticsearch.conf
# Add `--verbose --debug` if you need more info.
