# docker-logging

Easily pipe `docker logs` output from an
[AWS ECS](https://aws.amazon.com/ecs/) instance into Loggly.

See the aws-elasticsearch tag to pipe output to
[AWS Elasticsearch service](https://aws.amazon.com/elasticsearch-service/)
for later visualization with Kibana using Logstash (aka the ELK
Stack).

This repository may become deprecated when the support for the
[AWS CloudWatch Logs logging driver](https://docs.docker.com/engine/reference/logging/awslogs/)
is
[added to the ECS agent](https://github.com/aws/amazon-ecs-agent/issues/9). [@samuelkarp wrote the logging driver](https://github.com/docker/docker/pull/15495)
and happens to work for AWS on ECS, so this seems inevitable.

![Schematic of how Docker Logs get scraped into Elasticsearch using docker-logging logstash container.  Source: Docker-Logging.png; Find original visio file at Docker-Logging.vsdx](Docker-Logging.png)

# Local Setup

Prerequisites: Docker >= 1.8.  If you use Docker-compose, make sure
its version >= 1.5

1. Create an account with [Loggly](https://www.loggly.com/).
2. Create a customer token (Source Setup -> Customer Tokens -> Add New)
3. Start docker logging container & pass in the token you generated.

        docker run -it -p 12201:12201/udp \
		            -e LOGGLY_CUSTOMER_TOKEN=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
					pedros007/docker-logging:develop /start_logstash.sh

   If you do not have access to the `pedros007/docker-logging`
   Docker repo, build it yourself first:

         docker build -t pedros007/docker-logging .

4. Start a Docker container which you want logged using the Docker
   logging flags.  Here's a simple example:

         docker run --log-driver=gelf --log-opt gelf-address=udp://localhost:12201 \
                    busybox /bin/sh -c 'while true; do echo "Hello $(date)"; sleep 1; done'

# Deploying to an ECS Cluster

1. Create an Elasticsearch Cluster with
   [AWS Elasticsearch Service](https://aws.amazon.com/elasticsearch-service/)
   (see setup, above) and make a note of the Elasticsearch URL.

2. Configure ECS cluster.  Here's how you do it with CloudFormation:

  1. Your EC2 instances must use version >= 2015.09.e of the
     ECS-optimized AMI.  This is required to enable docker logging
     driver support.

  2. Fetch the Logstash configuration & pass in the Elasticsearch URL
     and start the Logstash container.  Add this to the `commands`
     section of your
     [AWS::Cloudformation::Init](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-init.html).

     ```
       "03_configure_docker_logstash": {
         "command": {
           "Fn::Join": [
             "",
             [
                 "#!/bin/bash -xe\n",
                 "docker run -d --restart=always  -p 12201:12201/udp",
				 " -e LOGGLY_CUSTOMER_TOKEN=",
				 {
				   "Ref": "LogglyCustomerToken"
				 },
				 " pedros007/docker-logging:develop /start_logstash.sh\n"
             ]
           ]
         }
       }
     ```

  3. Add LogglyCustomerToken to your `Parameters` section:

     ```
   "LogglyCustomerToken": {
     "Type": "String",
     "Description": "Token which enables access to Loggly.  Can have many tokens per Loggly account.  For details, see https://www.loggly.com/docs/customer-token-authentication-token"
   }
   ```

3. Submit an ECS task definition which uses the gelf logging
   driver. The ContainerDefinition should include a section like this:

        "logConfiguration": {
           "logDriver": "gelf",
           "options": {
             "gelf-address": "udp://localhost:12201"
            }
        }

  You can append an optional tag to the `options` map.  This tag is
  used to decide which Logstash grok/filters should be used.  See
  `conf/gelf_to_loggly.conf` for details.  Currently supported tags
  are `nginx`, `postgresql` & `rails`.

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
* See the `aws-elasticsearch` tag of this repository for a method to
  store logs in AWS Elasticsearch Service.
* There are many ways to pipe `docker logs` into Elasticsearch.
  [This docker-logstash repo](https://github.com/edefaria/docker-logstash)
  demonstrates a couple of options (gelf, lumberjack, syslog & tcp).
* Find user-configurable variables on lines starting with `ENV` in
  Dockerfile.

# Links

* [Grok Debugger](http://grokdebug.herokuapp.com/)
* [ELK and Docker-1.8](http://www.labouisse.com/how-to/2015/09/14/elk-and-docker-1-8/) and [ELK, Docker, and Spring Boot](http://www.labouisse.com/how-to/2015/09/23/elk-docker-and-spring-boot/)
* [Automating Docker Logging: ElasticSearch, Logstash, Kibana, and Logspout](http://nathanleclaire.com/blog/2015/04/27/automating-docker-logging-elasticsearch-logstash-kibana-and-logspout/)
