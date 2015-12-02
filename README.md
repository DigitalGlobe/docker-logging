# docker-logging

Pipe `docker logs` output into Elasticsearch for later visualization with Kibana using Logstash (aka the ELK Stack).

![Schematic of how Docker Logs get scraped into Elasticsearch using docker-logging logstash container.  Source: Docker-Logging.png; Find original visio file at Docker-Logging.vsdx](Docker-Logging.png)

# Local Setup

Prerequisites:  Docker >= 1.8.  If you use Docker-compose, make sure its version >= 1.5

1. Spin up an Elasticsearch server. The easiest way to do this is via
   the
   [AWS Elasticsearch Service](https://aws.amazon.com/elasticsearch-service/):

  1. Click "Create a new domain"
  2. Set a domain name
  3. Use the default options
  4. Set an Access Policy from a specific IP address (your personal IP).

2. Clone this repo & update the elasticsearch hostname. Note the
   format is `hostname:port`.  For example, with AWS Elasticsearch Service, use
   `search-pschmitt-es-test-3pm4igbk4q3nr5racsahpugud4.us-west-2.es.amazonaws.com:80`.  This is required as [Logstash does not allow Environment Variables in a conf file](https://github.com/elastic/logstash/issues/1910#issuecomment-59634201)).

        perl -pi -e "s|(?<=hosts => \[\")(.*)(?=\"\])|foobar:80|g" /conf/gelf_to_elasticsearch.conf

3. On the Docker host, start a Logstash container:

        docker run --rm -v $PWD/conf:/logstash-conf -p 12201:12201/udp logstash logstash -f /logstash-conf/gelf_to_elasticsearch.conf

4. Now you can start the containers which you want logged.  Here's a simple example:

        docker run --log-driver=gelf --log-opt gelf-address=udp://localhost:12201 busybox /bin/sh -c 'while true; do echo "Hello $(date)"; sleep 1; done'

# Deploying to an ECS Cluster

1. Create an Elasticsearch Cluster with
   [AWS Elasticsearch Service](https://aws.amazon.com/elasticsearch-service/)
   (see setup, above) and make a note of the Elasticsearch URL.
   You'll want to set the Access Policy so both the cluster and your
   IP address can access Elasticsearch & Kibana.

   Here's an example access policy for the "pschmitt-es-test"
   Elasticsearch Cluster where we grant access to AWS account XXXXXXXXXXXX and
   the IP addresses 192.168.1.1, 192.168.1.2:

   ```
{
    "Version": "2012-10-17",
    "Statement": [
        {
	    "Sid": "",
	    "Effect": "Allow",
	    "Principal": { "AWS": "*" },
	    "Action": "es:*",
	    "Resource": "arn:aws:es:us-west-2:XXXXXXXXXXXX:domain/pschmitt-es-test/*",
	    "Condition": {
		  "IpAddress": {
		      "aws:SourceIp": [ "192.168.1.1", "192.168.1.2" ]
		  }
	    }
	  },
	  {
	      "Effect": "Allow",
	      "Principal": { "AWS": [ "XXXXXXXXXXXX" ] },
	      "Action": [ "es:*" ],
	      "Resource": "arn:aws:es:us-west-2:XXXXXXXXXXXX:domain/pschmitt-es-test/*"
	  }
    ]
}
```

2. Create a bucket for conf files (make sure the name is unique!)

        aws s3api create-bucket --bucket flame-config

3. Upload Logstash config to the `flame-config` bucket.

        aws s3 cp conf/gelf_to_elasticsearch.conf s3://pschmitt-ecs-config/

4. Configure ECS cluster.  Here's how you do it with CloudFormation:

  1. The
     [AWS ECS-optimized AMI](https://aws.amazon.com/marketplace/pp/B00U6QTYI2)
     (2015.09.b) is running docker-1.7.1 as of this
     writing. [A post in the AWS forums](https://forums.aws.amazon.com/thread.jspa?messageID=683482)
     states "[AWS is] testing 1.9 RC and plan to deliver it this
     month."  It's not ready yet, so we must manually upgrade Docker.

     We also fetch the Logstash configuration & pass in the
     Elasticsearch URL and start the Logstash container.  Add this to
     the `commands` section of your
     [AWS::Cloudformation::Init](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-init.html).

     ```
     "03_upgrade_docker_for_log_driver_support": {
       "command": {
         "Fn::Join": [
             "",
             [
                 "#!/bin/bash -xe\n",
                 "service docker stop\n",
                 "cp /usr/bin/docker /usr/bin/docker.old\n",
                 "curl -o /usr/bin/docker https://get.docker.com/builds/Linux/x86_64/docker-1.9.0\n",
                 "service docker start\n"
             ]
           ]
         }
       },
       "04_configure_docker_logstash": {
         "command": {
           "Fn::Join": [
             "",
             [
                 "#!/bin/bash -xe\n",
                 "mkdir -p /etc/logstash/conf.d\n",
                 "aws s3 cp s3://pschmitt-ecs-config/gelf_to_elasticsearch.conf /etc/logstash/conf.d/gelf_to_elasticsearch.conf\n",
                 "perl -pi -e 's|(?<=hosts => \\[\")(.*)(?=\"\\])|",
                 {
                   "Ref": "ElasticsearchAddress"
                 },
                 "|g' /etc/logstash/conf.d/gelf_to_elasticsearch.conf\n",
                 "docker run -d --restart=always -v /etc/logstash/conf.d:/etc/logstash/conf.d -p 12201:12201/udp logstash logstash -f /etc/logstash/conf.d/gelf_to_elasticsearch.conf\n"
             ]
           ]
         }
       }
     ```

  2. Add ElasticsearchAddress to your `Parameters` section:

     ```
   "ElasticsearchAddress": {
     "Type": "String",
     "Description": "Host and port of Elasticsearch server for logging. With the AWS Elasticsearch Service use Endpoint:80. Ensure the access policy permits access."
   }
   ```

5. Submit an ECS task definition which uses the gelf logging
   driver. The ContainerDefinition should include a section like
   this:

        "logConfiguration": {
           "logDriver": "gelf",
           "options": {
             "gelf-address": "udp://localhost:12201",
             "tag": "nginx"
            }
        }

   Note the log option `tag` requires Docker > 1.9.  For Docker 1.8, use `gelf-tag`.  Otherwise, ECS may report

   > Failed to initialize logging driver: unknown log opt 'tag' for gelf log driver".

   As of this writing, the CloudFormation
   [AWS::ECS::TaskDefintiion](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-ecs-taskdefinition-containerdefinitions.html)
   does not support the
   [logConfiguration](http://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LogConfiguration.html)
   settings of an ECS TaskDefinition.  Watch the
   [Cloudformation Release History](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/ReleaseHistory.html)
   to be notified when this will be supported.


# Notes

* The
  [Graylog Extended Log Format (GELF)](https://www.graylog.org/resources/gelf/)
  driver communicates via UDP, which can silently dropping logging
  events.  TCP/syslog can provide a more robust solution.  See
  [this StackOverflow](http://stackoverflow.com/a/33816663/40785) for
  some more details.
* There are many ways to pipe `docker logs` into Elasticsearch.
  [This docker-logstash repo](https://github.com/edefaria/docker-logstash)
  demonstrates a couple of options (gelf, lumberjack, syslog & tcp).

# Links

* [Grok Debugger](http://grokdebug.herokuapp.com/)
* [ELK and Docker-1.8](http://www.labouisse.com/how-to/2015/09/14/elk-and-docker-1-8/) and [ELK, Docker, and Spring Boot](http://www.labouisse.com/how-to/2015/09/23/elk-docker-and-spring-boot/)
* [Automating Docker Logging: ElasticSearch, Logstash, Kibana, and Logspout](http://nathanleclaire.com/blog/2015/04/27/automating-docker-logging-elasticsearch-logstash-kibana-and-logspout/)
