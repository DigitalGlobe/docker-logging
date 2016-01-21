FROM logstash
MAINTAINER Peter Schmitt <peter.schmitt@digitalglobe.com>

RUN /opt/logstash/bin/plugin install logstash-output-amazon_es
RUN /opt/logstash/bin/plugin install logstash-output-loggly

COPY conf /etc/logstash/conf.d
COPY start_logstash.sh /
RUN chmod +x /start_logstash.sh

ENV LOGGLY_CUSTOMER_TOKEN "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
EXPOSE 12201/udp
CMD ["start_logstash.sh"]
