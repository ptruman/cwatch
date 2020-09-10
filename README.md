# cwatch

CWATCH (pronounced "quatch" is short for "container watch" - as this project started out as a "how do I do that?" to monitor containers.
It has since turned into an image watcher, but "cwatch" sounds better :)

As mentioned above, this started as a "how do I do that?" - and yes, other options are available (i.e. WatchTower) - but that wouldn't have taught me anything.  This has been an end to end experiment in getting (re)used to GitHub, DockerHub, Dockerfile and some scripting.

# Info

CWATCH is currently defaulted to run at 1am every day.  This will likely get made configurable later.  In a punch you can edit /etc/crontabs/root after setup :)

It <b>requires</b> that /var/run/docker.sock be bind mounted.  
It *assumes* that you are using the standard Docker Hub Registry for your images....

# Configuration

<b>Volumes</b>

* /var/run/docker.sock:/var/run/docker.sock:ro
* /tmp/cwatch.txt:/var/log/cwatch (optional)
* /etc/localtime:/etc/localtime:ro (optional *but* ensures correct timestamps)
* /etc/timezone:/etc/timezone:ro (optional *but* ensures correct timestamps)
* /etc/msmtprc:/etc/msmtprc:re (optional, if you have a functional msmtprc already)
<b>Environment</b>

* DEBUG - Can be set to 1 for verbose output.  Defaults to *0*
* BEHAVIOUR - Set to INCLUDE, EXCLUDE or ALL. Default to *ALL*
* CWATCH_ENABLE_EMAIL - Set this to 1 to enable msmtp based email
* CWATCH_EMAIL_TYPE - Set this to SMTP or GMAIL.  Used by SMTP type only.  (no default set)
* CWATCH_EMAIL_HOST - Set this to the required SMTP email host or IP. (no default set)
* CWATCH_EMAIL_PORT - Set this to the required SMTP email port, i.e. 25. (no default set)
* CWATCH_EMAIL_DOMAIN - Set this to the domain you send from (or your SMTP server expects). (no default set)
* CWATCH_EMAIL_TLS - Set this to ON or OFF.  Used by SMTP type only.  Defaults to *OFF*
* CWATCH_EMAIL_STARTTLS - Set this to ON of OFF. Used by SMTP type only. Defaults to *OFF*
* CWATCH_EMAIL_FROM - Set this to the email address email should come FROM and go TO (single address).  (no default set)
* CWATCH_EMAIL_GMAILUSER - Set this to the GMail address being used to provide GMail services.  Used by GMAIL type only. (no default set)
* CWATCH_EMAIL_GMAILPASSWORD - Set this to the GMail account password being used to provide GMail services.  Used by GMAIL type only. (no default set)
* DOCKER_REGISTRY - Set this to whatever Docker Registry host you need.  Defaults to *registry.hub.docker.com*
* DOCKER_REGISTRY_SERVICE - Set this to whatever Docker Registry service host you need. Defaults to *registry.docker.io*
* DOCKER_AUTH_SERVICE - Set this to whatever Docker Auth host you need. Defaults to *auth.docker.io*

# Usage (Docker Image/Container)

Once installed, CWATCH will run every 1am, outputting to it's docker log.
You can see the output via *docker logs cwatch* or in the logs window if you use Portainer.
It also writes logs to /var/log/cwatch - so you can mount that as a bind mount (see above) if you want a local file

Every 1am, CWATCH will run and check each container for a newer Docker Registry image, and advise if one is available.

# Usage (CLI)

Once installed, CWATCH can be called manually by executing one of:
* /usr/sbin/cwatch.sh (from within the container - i.e. after *docker exec -it cwatch /bin/bash*)
* docker exec cwatch /usr/sbin/cwatch.sh (from outside the container, on the docker host)

The above assumes your container is named *cwatch*

CWATCH can also take a single parameter argument, which should be an image - in the format library/image:tag - i.e. 
* docker exec cwatch /usr/sbin/cwatch.sh *ptruman/cwatch:latest* 

CWATCH will then *only* check the specified image, and provide output.  This is effectively the same as setting the CWATCH environment variable BEHAVIOUR=INCLUDE and putting the label CWATCH.INCLUDE=TRUE on a single container.

# Label Based Checking
CWATCH can read the following <b>labels</b> from running *containers* to INCLUDE or EXCLUDE their images from checking, although for this to work you <b>must</b> specify the environment variable BEHAVIOUR to be *INCLUDE* or *EXCLUDE* for them to be useful.
* CWATCH.INCLUDE - set to TRUE on a container you want to check the image for
* CWATCH.EXCLUDE - set to TRUE on a container you want to *not* check the image for

This means you do not need to set *every* Container with the labels, just the ones you want to explicitly include, or exclude.
The default BEHAVIOUR is ALL which will check ALL containers.

Specifying a(ny) command line parameter will override INCLUDE/EXCLUDE logic.

# Notes

* msmtp support is coming shortly (to send emails)
* Images with no obvious tag will default to "latest" - this may not be desirable in all instances
