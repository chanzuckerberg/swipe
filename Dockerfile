FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ARG MINIWDL_VERSION=1.4.3

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

#ADD miniwdl /tmp/miniwdl
#RUN cd /tmp/miniwdl && pip3 install --upgrade .
#RUN pip3 install miniwdl-s3parcp==0.0.5
RUN pip3 install miniwdl==${MINIWDL_VERSION} miniwdl-s3parcp==0.0.5

RUN pip3 install https://github.com/chanzuckerberg/miniwdl-plugins/archive/a579cfd28802ddaf99b63474216fda6eb8278f7a.zip#subdirectory=s3upload
# TODO: switch to proper release
RUN pip3 install https://github.com/chanzuckerberg/miniwdl-plugins/archive/a579cfd28802ddaf99b63474216fda6eb8278f7a.zip#subdirectory=s3upload

ADD miniwdl-plugins /tmp/miniwdl-plugins
RUN cd /tmp/miniwdl-plugins/s3parcp_download; pip install --upgrade .
RUN cd /tmp/miniwdl-plugins/sfn-wdl; pip install --upgrade .

RUN curl -Ls https://github.com/chanzuckerberg/s3parcp/releases/download/v1.0.3-alpha/s3parcp_1.0.3-alpha_linux_amd64.tar.gz | tar -C /usr/bin -xz s3parcp

ADD https://raw.githubusercontent.com/chanzuckerberg/miniwdl/v${MINIWDL_VERSION}/examples/clean_download_cache.sh /usr/local/bin
ADD scripts/init.sh /usr/local/bin
RUN chmod +x /usr/local/bin/clean_download_cache.sh

# docker.io is the largest package at 250MB+ / half of all package disk space usage.
# The docker daemons never run inside the container - removing them saves 150MB+
RUN rm -f /usr/bin/dockerd /usr/bin/containerd*

RUN cd /usr/bin; curl -O https://amazon-ecr-credential-helper-releases.s3.amazonaws.com/0.4.0/linux-amd64/docker-credential-ecr-login
RUN chmod +x /usr/bin/docker-credential-ecr-login
RUN mkdir -p /root/.docker
RUN jq -n '.credsStore="ecr-login"' > /root/.docker/config.json
ENTRYPOINT ["/usr/local/bin/init.sh"]
