##!/bin/bash
# CWATCH (Docker Image Checker) V4.0
# (C) 2020 Functional Simplicity & Tech Bobbins
# All Rights Reserved
#
# Use of this scripts is at executors own risk
#
# Set DEBUG to 1 if you want full sdtdout...
DEBUG=0
#
StartTime=`date +%s`
echo "CWATCH >> Starting up...please wait..."
if [ -f /var/run/docker.sock ]; then
        # List and count images
        Images=(`docker image ls | grep -v REPOSITORY | awk '{split($0,ImgArr," "); print ImgArr[1]}'`)
        Tags=(`docker image ls | grep -v REPOSITORY | awk '{split($0,ImgArr," "); print ImgArr[2]}'`)
        ImgCount=${#Images[@]}
        if [ $DEBUG = 1 ]; then
                echo "CWATCH >> Found a total of $ImgCount images"
        fi
        # Instantiate arrays
        UpdateOk=()
        UpdateReq=()
        UpdateQuery=()
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
                                echo "CWATCH >> $Image shows no tag - assuming 'latest'"
                        fi
                        Tag="latest"
                fi
                # Nice debug output
                if [ $DEBUG = 1 ]; then
                        echo "CWATCH >> Now checking $Image"
                        echo "CWATCH >> Image Name : $Image"
                        echo "CWATCH >> Image Tag  : $Tag"
                fi
                # Check we have a repository AND an image (script does not handle images sans repositories yet...
                if [[ ! $Image =~ "/" ]]; then
                        Image="library/$Image"
                fi
                # Grab existing (running) image SHA256 digest
                RunningRepoDigestRaw=`docker image inspect $Image:$Tag | jq -r '.[0].Id'`
                RunningRepoDigest=`echo $RunningRepoDigestRaw | awk '{split($0,RepoDigestArr,":"); print RepoDigestArr[2]}'`
                if [ $DEBUG = 1 ]; then
                        echo "CWATCH >> Ext Digest : $RunningRepoDigest"
                fi
                # Setup OAUTH request to query Docker Hub
                AUTH_SERVICE="registry.docker.io"
                AUTH_REGISTRY="registry.hub.docker.com"
                AUTH_SCOPE="repository:$Image:pull"
                AUTH_TOKEN=$(curl -fsSL "https://auth.docker.io/token?service=$AUTH_SERVICE&scope=$AUTH_SCOPE" | jq --raw-output '.token')
                # Pull most receent image/tag digest
                LiveDigestRaw=`curl -fsSL  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Authorization: Bearer $AUTH_TOKEN" "$AUTH_REGISTRY/v2/$Image/manifests/$Tag" | jq --raw-output '.config.digest'`
                LiveDigest=`echo $LiveDigestRaw | awk '{split($0,LiveDigestArr,":"); print LiveDigestArr[2]}'`
                # Munge any weird HTTP header chars back out...
                LiveDigestEd=`echo "$LiveDigest" | sed "s/[^[:alnum:]-]//g"`
                if [ $DEBUG = 1 ]; then
                        echo "CWATCH >> Live Digest: $LiveDigestEd"
                fi
                # Check if SHA256 digests match
                if [[ $RunningRepoDigest = $LiveDigestEd ]]; then
                        # If match - nothing required
                        if [ $DEBUG = 1 ]; then
                                echo "CWATCH >> $Image:Tag - NO UPDATE NEEDED "
                        fi
                        UpdateOk+=("$Image:$Tag")
                else
                        # If mismatch, flag for update
                        if [ $DEBUG = 1 ]; then
                                echo "CWATCH >> $Image:$Tag - UPDATE REQUIRED"
                        fi
                        UpdateReq+=("$Image:$Tag")
                fi
        done
        # Dump findings
        echo "CWATCH >> Found ${#UpdateReq[@]} of $ImgCount containers that need an update.  ${#UpdateOk[@]} are up to date."
        # Updates required
        if [ ${#UpdateReq[@]} > 0 ]; then
                echo "CWATCH >> Images needing an update :"
                for i in "${UpdateReq[@]}"
                do
                        echo "  >> $i"
                done
        fi
else
        echo "CWATCH >> /var/run/docker.sock not found - please ensure file is available/mounted for the CWATCH container"
        echo "CWATCH >> Terminating."
fi
EndTime=`date +%s`
TotalTime=`expr $EndTime - $StartTime`
echo "CWATCH >> Finished.  Took $TotalTime seconds."

