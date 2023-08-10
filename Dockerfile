FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
# currently, there is an issue in v1.5.3 so we can't upgrade until it is resolved https://github.com/chanzuckerberg/miniwdl/issues/607
ARG MINIWDL_VERSION=1.5.2

LABEL maintainer="IDseq Team idseq-tech@chanzuckerberg.com"

RUN sed -i s/archive.ubuntu.com/us-west-2.ec2.archive.ubuntu.com/ /etc/apt/sources.list; \
        echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/98idseq; \
        echo 'APT::Install-Suggests "false";' > /etc/apt/apt.conf.d/99idseq

RUN apt-get -q update && apt-get -q install -y \
        git \
        jq \
        moreutils \
        pigz \
        pixz \
        aria2 \
        httpie \
        curl \
        wget \
        zip \
        unzip \
        zlib1g-dev \
        pkg-config \
        apt-utils \
        libbz2-dev \
        liblzma-dev \
        software-properties-common \
        libarchive-tools \
        liblz4-tool \
        lbzip2 \
        docker.io \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        python3-requests \
        python3-yaml \
        python3-dateutil \
        python3-psutil \
        python3-boto3 \
        awscli

# miniwdl requires us to pin importlib-metadata because v5.0.0 is a breaking change
#   miniwdl v1.7.1 has an update to be compatible with importlib-metadata v5.0.0 but we can't
#   upgrade because of this issue https://github.com/chanzuckerberg/miniwdl/issues/607 in miniwdl
RUN pip3 install importlib-metadata==4.13.0
RUN pip3 install miniwdl==${MINIWDL_VERSION}
RUN pip3 install urllib3==1.26.16

RUN curl -Ls https://github.com/chanzuckerberg/s3parcp/releases/download/v1.0.1/s3parcp_1.0.1_linux_amd64.tar.gz | tar -C /usr/bin -xz s3parcp

ADD https://raw.githubusercontent.com/chanzuckerberg/miniwdl/v${MINIWDL_VERSION}/examples/clean_download_cache.sh /usr/local/bin
ADD scripts/init.sh /usr/local/bin
RUN chmod +x /usr/local/bin/clean_download_cache.sh

# docker.io is the largest package at 250MB+ / half of all package disk space usage.
# The docker daemons never run inside the container - removing them saves 150MB+
RUN rm -f /usr/bin/dockerd /usr/bin/containerd*

ADD miniwdl-plugins miniwdl-plugins

RUN pip install miniwdl-plugins/s3upload
RUN pip install miniwdl-plugins/sfn_wdl
RUN pip install miniwdl-plugins/s3parcp_download

RUN cd /usr/bin; curl -O https://amazon-ecr-credential-helper-releases.s3.amazonaws.com/0.4.0/linux-amd64/docker-credential-ecr-login
RUN chmod +x /usr/bin/docker-credential-ecr-login
RUN mkdir -p /root/.docker
RUN jq -n '.credsStore="ecr-login"' > /root/.docker/config.json
ENTRYPOINT ["/usr/local/bin/init.sh"]
