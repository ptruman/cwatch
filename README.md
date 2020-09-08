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
* /tmp/cwatch.txt:/var/log/cwatch *(optional)*

<b>Environment</b>

* DEBUG - Can be set to 1 for verbose output.  Defaults to *0*
* DOCKER_REGISTRY - Set this to whatever Docker Registry host you need.  Defaults to *registry.hub.docker.com*
* DOCKER_REGISTRY_SERVICE - Set this to whatever Docker Registry service host you need. Defaults to *registry.docker.io*
* DOCKER_AUTH_SERVICE - Set this to whatevre Docker Auth host you need. Defaults to *auth.docker.io*

# Usage

Once installed, CWATCH will run every 1am, outputting to it's docker log.
You can see the output via *docker logs cwatch* or in the logs window if you use Portainer.
It also writes logs to /var/log/cwatch - so you can mount that as a bind mount (see above) if you want a local file

Every 1am, CWATCH will run and check each container for a newer Docker Registry image, and advise if one is available.

# Notes

* msmtp support is coming shortly (to send emails)
* Images with no obvious tag will default to "latest" - this may not be desirable in all instances
