FROM logstash
MAINTAINER Peter Schmitt <peter.schmitt@digitalglobe.com>

RUN /opt/logstash/bin/plugin install logstash-output-amazon_es

COPY conf /etc/logstash/conf.d
COPY start_logstash.sh /
RUN chmod +x /start_logstash.sh

ENV AWS_REGION "us-west-2"
ENV ELASTICSEARCH_HOST "search-pschmitt-iam-access-vx6u2y3upcsmgnu4bcihdf3kge.us-west-2.es.amazonaws.com"
ENV ENVIRONMENT "development"
EXPOSE 12201/udp
CMD ["start_logstash.sh"]
