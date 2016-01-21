#!/bin/bash
set -e

# Setup logstash config based on environment variables set via
# Docker. Note that logstash config files cannot parse environment
# variables https://github.com/elastic/logstash/issues/1910#issuecomment-59634201

# Note the Perl Regex tricks: 
# (?<=foo) positive lookbehind
# (?=foo) positive lookahead
# test with `grep -Po PATTERN`
# http://unix.stackexchange.com/a/103008/94258
perl -pi -e "s|(?<=key => \")(.*)(?=\")|${LOGGLY_CUSTOMER_TOKEN}|g" /etc/logstash/conf.d/gelf_to_loggly.conf

# Run as user logstash
set -- gosu logstash
logstash -f /etc/logstash/conf.d/gelf_to_loggly.conf
# Add `--verbose --debug` if you need more info.
