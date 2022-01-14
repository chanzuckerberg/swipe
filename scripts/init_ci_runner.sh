# This script is sourced by GitHub Actions.

set -a
DEBIAN_FRONTEND=noninteractive
TERRAFORM_VERSION=0.15.0
GH_CLI_VERSION=1.9.2
LC_ALL=C.UTF-8
LANG=C.UTF-8
TF_CLI_ARGS_apply="--auto-approve"
set +a

sudo apt-get -qq update
sudo apt-get -qq install -o=Dpkg::Use-Pty=0 --yes build-essential python3-dev unzip
sudo gem install --quiet statelint
curl -OLs https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
sudo unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin
pip install -r requirements-dev.txt
docker swarm init

set -x
