##!/bin/bash
# CWATCH (Docker Image Checker) V4.2
# (C) 2020 Peter Truman
# All Rights Reserved
#
# Use of this scripts is at executors own risk

# Set DEBUG to 1 if you want full sdtdout...
if [ ! $DEBUG ]; then
        DEBUG=0
fi

# Check for Registry ENVs
if [ ! $DOCKER_REGISTRY ]; then
        DOCKER_REGISTRY="registry.hub.docker.com"
fi
if [ ! $DOCKER_REGISTRY_SERVICE ]; then
        DOCKER_REGISTRY_SERVICE="registry.docker.io"
fi
if [ ! $DOCKER_AUTH_SERVICE ]; then
        DOCKER_AUTH_SERVICE="auth.docker.io"
fi

# Instantiate arrays
UpdateOk=()
UpdateReq=()
UpdateQuery=()
OUTPUT=()

# Output function
SendOutput()
{
        OUTPUT+=("$@")
        if [ -S /var/run/docker.sock ]; then
                echo "$@" >> /proc/1/fd/1
        fi
}

TMPFile=$RANDOM

# Start processing
StartTime=`date +%s`
SendOutput "CWATCH >> Starting up...please wait..."
# Check we have a docker.sock file accessible - we cannot proceed without Docker!
if [ -S /var/run/docker.sock ]; then
        # List and count images/tags
        Images=(`docker image ls | grep -v REPOSITORY | awk '{split($0,ImgArr," "); print ImgArr[1]}'`)
        Tags=(`docker image ls | grep -v REPOSITORY | awk '{split($0,ImgArr," "); print ImgArr[2]}'`)
        ImgCount=${#Images[@]}
        if [ $DEBUG = 1 ]; then
                SendOutput "CWATCH >> Found a total of $ImgCount images"
        fi
        # Process each Image
        for (( i=0; i<${#Images[@]}; i++))
        do
                CurrentImg=${Images[$i]}
                # Extract image name
                Image=${Images[$i]}
                # Check if image has a tag
                Tag=${Tags[$i]}
                if [ $Tag = "<none>" ]; then
                        if [ $DEBUG = 1 ]; then
                                SendOutput "CWATCH >> $Image shows no tag - assuming 'latest'"
                        fi
                        Tag="latest"
                fi
                # Nice debug output
                if [ $DEBUG = 1 ]; then
                        SendOutput "CWATCH >> Now checking $Image"
                        SendOutput "CWATCH >> Image Name : $Image"
                        SendOutput "CWATCH >> Image Tag  : $Tag"
                fi
                # Check we have a repository AND an image (script does not handle images sans repositories yet...
                if [[ ! $Image =~ "/" ]]; then
                        Image="library/$Image"
                fi
                # Grab existing (running) image SHA256 digest
                RunningRepoDigestRaw=`docker image inspect $Image:$Tag | jq -r '.[0].Id'`
                RunningRepoDigest=`echo $RunningRepoDigestRaw | awk '{split($0,RepoDigestArr,":"); print RepoDigestArr[2]}'`
                if [ $DEBUG = 1 ]; then
                        SendOutput "CWATCH >> Ext Digest : $RunningRepoDigest"
                fi
                # Setup OAUTH request to query Docker Hub
                AUTH_SCOPE="repository:$Image:pull"
                AUTH_TOKEN=$(curl -fsSL "https://$DOCKER_AUTH_SERVICE/token?service=$DOCKER_REGISTRY_SERVICE&scope=$AUTH_SCOPE" | jq --raw-output '.token')
                # Pull most receent image/tag digest
                LiveDigestRaw=`curl -fsSL  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Authorization: Bearer $AUTH_TOKEN" "$DOCKER_REGISTRY/v2/$Image/manifests/$Tag" | jq --raw-output '.config.digest'`
                LiveDigest=`echo $LiveDigestRaw | awk '{split($0,LiveDigestArr,":"); print LiveDigestArr[2]}'`
                # Munge any weird HTTP header chars back out...
                LiveDigestEd=`echo "$LiveDigest" | sed "s/[^[:alnum:]-]//g"`
                if [ $DEBUG = 1 ]; then
                        SendOutput "CWATCH >> Live Digest: $LiveDigestEd"
                fi
                # Check if SHA256 digests match
                if [[ $RunningRepoDigest = $LiveDigestEd ]]; then
                        # If match - nothing required
                        if [ $DEBUG = 1 ]; then
                                SendOutput "CWATCH >> $Image:Tag - NO UPDATE NEEDED "
                        fi
                        UpdateOk+=("$Image:$Tag")
                else
                        # If mismatch, flag for update
                        if [ $DEBUG = 1 ]; then
                                SendOutput "CWATCH >> $Image:$Tag - UPDATE REQUIRED"
                        fi
                        UpdateReq+=("$Image:$Tag")
                fi
        done
        # Dump findings
        SendOutput "CWATCH >> Found ${#UpdateReq[@]} of $ImgCount containers that need an update.  ${#UpdateOk[@]} are up to date."
        # Updates required
        if [ ${#UpdateReq[@]} > 0 ]; then
                SendOutput "CWATCH >> Images needing an update :"
                for i in "${UpdateReq[@]}"
                do
                        SendOutput "  >> $i"
                done
        fi
else
        echo "CWATCH >> /var/run/docker.sock not found - please ensure file is available/mounted for the CWATCH container."
        echo "CWATCH >> Terminating."
fi
EndTime=`date +%s`
TotalTime=`expr $EndTime - $StartTime`
SendOutput "CWATCH >> Finished.  Took $TotalTime seconds."
for i in "${OUTPUT[@]}"
do
        echo "$i"
        echo "$i" >> /proc/1/fd/1
        echo "$i" >> /var/log/cwatch
done

