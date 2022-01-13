#!/bin/bash
set -a
if [ -f /etc/environment ]; then source /etc/environment; fi
if [ -f /etc/default/locale ]; then source /etc/default/locale; else export LC_ALL=C.UTF-8 LANG=C.UTF-8; fi
set +a

if [ -n "${AWS_ENDPOINT_URL-}" ]; then
  export aws="aws --endpoint-url ${AWS_ENDPOINT_URL}"
else
  export aws="aws"
fi

check_for_termination() {
  count=0
  while true; do
    if TOKEN=`curl -m 10 -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` && curl -H "X-aws-ec2-metadata-token: $TOKEN" -sf http://169.254.169.254/latest/meta-data/spot/instance-action; then
      echo WARNING: THIS SPOT INSTANCE HAS BEEN SCHEDULED FOR TERMINATION >> /dev/stderr
    fi
    # Print an update every 5 mins
    if [ $((count++ % 60)) -eq 0 ]; then
      echo $(date --iso-8601=seconds) termination check
    fi
    sleep 10
  done
}

put_metric() {
    aws cloudwatch put-metric-data --metric-name $1 --namespace $APP_NAME --unit Percent --value $2 --dimensions SFNCurrentState=$SFN_CURRENT_STATE
}

put_metrics() {
  while true; do
    put_metric ScratchSpaceInUse $(df --output=pcent /mnt | tail -n 1 | cut -f 1 -d %)
    put_metric CPULoad $(cat /proc/loadavg | cut -f 1 -d ' ' | cut -f 2 -d .)
    put_metric MemoryInUse $(python3 -c 'import psutil; m=psutil.virtual_memory(); print(100*(1-m.available/m.total))')
    sleep 60
  done
}

check_for_termination &
put_metrics &

mkdir -p /mnt/download_cache; touch /mnt/download_cache/_miniwdl_flock

clean_wd() {
  (shopt -s nullglob;
  for wf_log in /mnt/20??????_??????_*/workflow.log; do
    flock -n $wf_log rm -rf $(dirname $wf_log) || true;
  done;
  flock -x /mnt/download_cache/_miniwdl_flock clean_download_cache.sh /mnt/download_cache $DOWNLOAD_CACHE_MAX_GB)
}
clean_wd
df -h / /mnt
export MINIWDL__S3_PROGRESSIVE_UPLOAD__URI_PREFIX=$(dirname "$WDL_OUTPUT_URI")
if [ -f /etc/profile ]; then source /etc/profile; fi
miniwdl --version

# Env vars that need to be forwarded to miniwdl's tasks in AWS Batch.
BATCH_SWIPE_ENVVARS="AWS_DEFAULT_REGION AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"
# set $WDL_PASSTHRU_ENVVARS to a list of space-separated env var names
# to pass the values of those vars to miniwdl's task containers.
PASSTHRU_VARS=( $BATCH_SWIPE_ENVVARS $WDL_PASSTHRU_ENVVARS )
PASSTHRU_ARGS=${PASSTHRU_VARS[@]/#/--env }

set -euo pipefail
export CURRENT_STATE=$(echo "$SFN_CURRENT_STATE" | sed -e s/SPOT// -e s/EC2//)

aws s3 cp "$WDL_WORKFLOW_URI" .
aws s3 cp "$WDL_INPUT_URI" wdl_input.json

handle_error() {
  OF=wdl_output.json;
  EP=.cause.stderr_file;
  if jq -re .error $OF; then
    if jq -re $EP $OF; then
      if tail -n 1 $(jq -r $EP $OF) | jq -re .wdl_error_message; then
        tail -n 1 $(jq -r $EP $OF) > $OF;
      fi;
    fi;
    aws s3 cp $OF "$WDL_OUTPUT_URI";
  fi
}

trap handle_error EXIT
miniwdl run $PASSTHRU_ARGS --dir /mnt $(basename "$WDL_WORKFLOW_URI") --input wdl_input.json --verbose --error-json -o wdl_output.json
clean_wd
