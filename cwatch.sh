#!/bin/bash
# CWATCH (Docker Image Checker) V5
# (C) 2020 Peter Truman
# All Rights Reserved
#
# Use of this scripts is at executors own risk. 
# See the Licence at https://github.com/ptruman/cwatch/blob/master/LICENSE or in the local LICENSE file as appropriate

CWATCHVer=5.1

##### PROCESS DEFAULT ENVIRONMENT VARIABLES #####

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

# Handle Image processing rules
if [ ! $BEHAVIOUR ]; then
	BEHAVIOUR=ALL
	DEFBEHAV=1
else
	BEHAVIOUR=${BEHAVIOUR^^}
	DEFBEHAV=0
fi
#####

# Check if we are in a container...
IsContainer=0
FirstPID=`ps -aef | grep -v PID | sort | head -1| awk '{print $1}'`
FirstProc=`ps -aef | grep -v PID | sort | head -1| awk '{print $4}'`
if [ $FirstPID = 1 ]; then
        if [ $FirstProc = "crond" ]; then
                IsContainer=1
        fi
fi

# Instantiate arrays
UpdateOk=()
UpdateReq=()
UpdateQuery=()
OUTPUT=()

# Define Output function
SendOutput()
{
	OutputType="${@:1:1}"
	RemOutput="${@:2}"
	if [ $DEBUG = 1 ]; then
		if [ $IsContainer = 1 ]; then
                        echo "$RemOutput" >> /proc/1/fd/1
			echo "$RemOutput" 
                else
                        echo "$RemOutput"
                fi
		OUTPUT+=("$RemOutput")
	else
		if [ $OutputType = "S" ]; then
			OUTPUT+=("$RemOutput")
		fi 
	fi
}

TMPFile="/tmp/$RANDOM"

# Start processing
StartTime=`date +%s`
SendOutput S "CWATCH >> Starting up...please wait...($CWATCHVer)"

# Check where we are...
if [ $IsContainer = 1 ]; then
	SendOutput D "CWATCH >> Running in a container"
else
	SendOutput D "CWATCH >> Running locally"
fi
# Check Behaviour settings
if [ $BEHAVIOUR = "ALL" ]; then
	if [ $DEFBEHAV = 1 ]; then
		SendOutput D "CWATCH >> Behaviour : INCLUDE:ALL (Defaulted)"
	else
                SendOutput D "CWATCH >> Behaviour : INCLUDE:ALL (SetByEnv)"
	fi
fi
if [ $BEHAVIOUR = "INCLUDE" ]; then
        SendOutput D "CWATCH >> Behaviour : INCLUDE:Explicit (SetByEnv)"
fi
if [ $BEHAVIOUR = "EXCLUDE" ]; then
	SendOutput D "CWATCH >> Behaviour : EXCLUDE:Explcit (SetByEnv)"
fi

# Check Email status/config
if [ ! -f /etc/msmtprc ]; then
	# No email config found - is email enabled?
	if [ $CWATCH_ENABLE_EMAIL ]; then
	        if [ $CWATCH_ENABLE_EMAIL = 1 ]; then
	                if [ $CWATCH_EMAIL_TYPE = "SMTP" ]; then
				SendOutput D "CWATCH >> Creating email template."
				# Check for TLS settings
		                if [ ! $CWATCH_EMAIL_TLS ]; then
		                        CWATCH_EMAIL_TLS=off
		                else
		                        $CWATCH_EMAIL_TLS=${CWATCH_EMAIL_TLS,,}
		                fi
		                if [ ! $CWATCH_EMAIL_STARTTLS ]; then
		                        CWATCH_EMAIL_STARTTLS=off
		                else
		                        $CWATCH_EMAIL_TLS=${CWATCH_EMAIL_STARTTLS,,}
		                fi
	                        cat << EOF > /etc/msmtprc
### Automatically generated on container start. See documentation on how to set!
account default
host $CWATCH_EMAIL_HOST
port $CWATCH_EMAIL_PORT
domain $CWATCH_EMAIL_DOMAIN
from $CWATCH_EMAIL_FROM
maildomain local
tls $CWATCH_EMAIL_TLS
tls_starttls $CWATCH_EMAIL_STARTTLS
tls_certcheck off
EOF
	                fi
	                if [ $CWATCH_EMAIL_TYPE = "GMAIL" ]; then
	                        cat << EOF > /etc/msmtprc
### Automatically generated on container start. See documentation on how to set!
account default
host smtp.gmail.com
port 587
from $CWATCH_EMAIL_FROM
user $CWATCH_EMAIL_GMAILUSER
tls on
tls_starttls on
password $CWATCH_EMAIL_GMAILPASSWORD
EOF
	                fi
	        fi
	fi
fi

# Check we have a docker.sock file accessible - we cannot proceed without Docker!
if [ -S /var/run/docker.sock ]; then
        if [ $1 ]; then
                SendOutput S "CWATCH >> cmdline argument received - checking for an image/tag combo."
                if [ `echo "$1" | awk -F: '{print $2}'` ]; then
                        RepoImg=`echo "$1" | awk -F\/ '{print $1}'`
			if [[ "$RepoImg" =~ "/" ]]; then
				Repo=`echo "$1" | awk -F\/ '{print $1}'`
				Img=`echo "$1" | awk -F\/ '{print $2}'`
			else
				Repo="library"
				Img=`echo "$1" | awk -F\/ '{print $1}'`
			fi
                        Tag=`echo "$1" | awk -F\/ '{print $2}'`
			echo "Found $Repo $Img $Tag"
                else
                        SendOutput S "CWATCH >> No Img/Tag combo found in the supplied argument."
			Images=()
                fi
                #Img=`echo $1 awk -F\/ '{print $2}' | awk -F\: '{print $1}'`
                #Tag=`echo $1 awk -F\/ '{print $2}' | awk -F\: '{print $2}'`
        else
	        # List and count images/tags
	        Images=(`docker image ls | grep -v REPOSITORY | awk '{split($0,ImgArr," "); print ImgArr[1]}'`)
	        Tags=(`docker image ls | grep -v REPOSITORY | awk '{split($0,ImgArr," "); print ImgArr[2]}'`)
		# Check for CWATCH labels
		Included=(`docker ps -f "label=CWATCH.INCLUDE=TRUE" | grep -v CREATED| awk '{split($0,ImgArr," "); print ImgArr[2]}'`)
		Excluded=(`docker ps -f "label=CWATCH.EXCLUDE=TRUE" | grep -v CREATED| awk '{split($0,ImgArr," "); print ImgArr[2]}'`)
	        IncImgCount=${#Included[@]}
	        ExcImgCount=${#Excluded[@]}
	fi
        ImgCount=${#Images[@]}
        SendOutput D "CWATCH >> Found a total of $ImgCount images"
	if [ $ImgCount -gt 0 ]; then
		SendOutput D "CWATCH >> $IncImgCount force included - $ExcImgCount force excluded"
	else
		ImgCount=0
	fi
        # Process each Image
	CheckCount=0
        for (( i=0; i<${#Images[@]}; i++))
        do
		OkToProcess=0
		# Handle errors with CLI arguments
		if [ ! ${Images[$i]} ]; then
			exit for
		fi
                CurrentImg=${Images[$i]}
                # Extract image name
                Image=${Images[$i]}
                # Check if image has a tag
                Tag=${Tags[$i]}
                if [ $Tag = "<none>" ]; then
                        SendOutput D "CWATCH >> $Image shows no tag - assuming 'latest'"
                        Tag="latest"
                fi
                # Check we have a repository AND an image (script does not handle images sans repositories yet...
                if [[ ! $Image =~ "/" ]]; then
                        Image="library/$Image"
                fi
		CombinedImgTag="$Image:$Tag"
		# Disposition Image based on Behaviour
		if [ $BEHAVIOUR = "ALL" ]; then
			OkToProcess=1
			SendOutput D "CWATCH >> Including $CombinedImgTag (INCLUDE:ALL)"
		fi
		if [ $BEHAVIOUR = "INCLUDE" ]; then
			if [[ " ${Included[@]} " =~ " ${CombinedImgTag} " ]]; then
				OkToProcess=1
				SendOutput D "CWATCH >> Including $CombinedImgTag (INCLUDE:Explicit)"
			else
				OkToProcess=0
				SendOutput D "CWATCH >> Excluding $CombinedImgTag (INCLUDE:Explicit)"
			fi
		fi
                if [ $BEHAVIOUR = "EXCLUDE" ]; then
                        if [[ " ${Excluded[@]} " =~ " ${CombinedImgTag} " ]]; then
	                        OkToProcess=0
				SendOutput D "CWATCH >> Excluding $CombinedImgTag (EXCLUDE:Explicit)"
			else
				OkToProcess=1
				SendOutput D "CWATCH >> Including $CombinedImgTag (EXCLUDE:Explicit)"
			fi
                fi
		if [ $OkToProcess = 1 ]; then
			CheckCount=`expr $CheckCount + 1`
	                # Nice debug output
	                SendOutput D "CWATCH >> Now checking $CombinedImgTag"
	                # Grab existing (running) image SHA256 digest
	                RunningRepoDigestRaw=`docker image inspect $Image:$Tag | jq -r '.[0].Id'`
	                RunningRepoDigest=`echo $RunningRepoDigestRaw | awk '{split($0,RepoDigestArr,":"); print RepoDigestArr[2]}'`
	                SendOutput D "CWATCH >> Ext Digest : $RunningRepoDigest"
	                # Setup OAUTH request to query Docker Hub
	                AUTH_SCOPE="repository:$Image:pull"
	                AUTH_TOKEN=$(curl -fsSL "https://$DOCKER_AUTH_SERVICE/token?service=$DOCKER_REGISTRY_SERVICE&scope=$AUTH_SCOPE" | jq --raw-output '.token')
	                # Pull most receent image/tag digest
	                LiveDigestRaw=`curl -fsSL  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Authorization: Bearer $AUTH_TOKEN" "$DOCKER_REGISTRY/v2/$Image/manifests/$Tag" | jq --raw-output '.config.digest'`
	                LiveDigest=`echo $LiveDigestRaw | awk '{split($0,LiveDigestArr,":"); print LiveDigestArr[2]}'`
	                # Munge any weird HTTP header chars back out...
	                LiveDigestEd=`echo "$LiveDigest" | sed "s/[^[:alnum:]-]//g"`
	                SendOutput D "CWATCH >> Live Digest: $LiveDigestEd"
	                # Check if SHA256 digests match
	                if [[ $RunningRepoDigest = $LiveDigestEd ]]; then
	                        # If match - nothing required
	                        SendOutput D "CWATCH >> Disposition for $Image:$Tag - NO UPDATE NEEDED "
	                        UpdateOk+=("$CombingImgTag")
	                else
	                        # If mismatch, flag for update
	                        SendOutput D "CWATCH >> Disposition for $Image:$Tag - UPDATE REQUIRED"
	                        UpdateReq+=("$CombinedImgTag")
	                fi
		fi
        done
	UnChecked=`expr $ImgCount - $CheckCount`
        # Dump findings
        SendOutput S "CWATCH >> Checked $CheckCount of $ImgCount images."
	SendOutput S "CWATCH >> Found ${#UpdateReq[@]} of $CheckCount images needing an update.  ${#UpdateOk[@]} up to date. $UnChecked not checked."
        # Updates required
	NumUpdates=${#UpdateReq[@]}
        if [ "$NumUpdates" -gt 0 ]; then
                SendOutput S "CWATCH >> Images needing an update :"
                for i in "${UpdateReq[@]}"
                do
                        SendOutput S "  >> $i"
                done
        fi
else
        SendOutput D "CWATCH >> /var/run/docker.sock not found - please ensure file is available/mounted for the CWATCH container."
        SendOutput D "CWATCH >> Terminating."
fi

# Provide output
MDate=`date`
if [ "$CWATCH_ENABLE_EMAIL" = 1 ]; then
	echo "From: $CWATCH_EMAIL_FROM" >> $TMPFile
	echo "To: $CWATCH_EMAIL_FROM" >> $TMPFile
	echo "Subject: CWATCH Output ($MDate) - $NumUpdates image(s) to update" >> $TMPFile
fi

for (( i=0; i<${#OUTPUT[@]}; i++))
do
	# Log to stdout (for CLI)
	# Log to Docker log if within a container
	if [ $IsContainer = 1 ]; then
		# Only write to Docker log if DEBUG has not already been written
		if [ $DEBUG = 0 ]; then
		        echo "${OUTPUT[$i]}" >> /proc/1/fd/1
		fi
	fi 
	# Log to /var/log/cwatch either way
        echo "${OUTPUT[$i]}" >> /var/log/cwatch
	# Should we be emailing?
	if [ $CWATCH_ENABLE_EMAIL = 1 ]; then
	#        SendOutput D "CWATCH >> Spooling email"
		echo "${OUTPUT[$i]}" >> $TMPFile
	fi
done

EndTime=`date +%s`
TotalTime=`expr $EndTime - $StartTime`
OutDate=`date`
SendOutput S "CWATCH >> Finished.  Took $TotalTime seconds. ($OutDate)"
echo "CWATCH >> Finished.  Took $TotalTime seconds. ($OutDate)" >> $TMPFile

# Send email
if [ "$CWATCH_ENABLE_EMAIL" = 1 ]; then
        SendOutput D "CWATCH >> Attempting to send email to $CWATCH_EMAIL_FROM"
        cat $TMPFile | msmtp $CWATCH_EMAIL_FROM
fi

