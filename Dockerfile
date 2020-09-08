# Dockerfile for CWATCH
FROM alpine
MAINTAINER peter.truman+dh@gmail.com

# Set base labels
LABEL CWATCH=V4
LABEL maintainer=peter.truman+dh@gmail.com

# Set environment

# Grab pre-requisites
RUN apk update \
        apk upgrade \
        apk add docker msmtp curl jq \
        curl https://raw.githubusercontent.com/ptruman/cwatch/master/cwatch.sh > /usr/sbin/cwatch.sh \
        chmod a+rx /usr/sbin/cwatch.sh \
        touch /var/log/cwatch \
        echo "*/2       *       *       *       *       /usr/sbin/cwatch.sh > /var/log/cwatch" >> /etc/crontabs/root

CMD ["crond", "-f"]
