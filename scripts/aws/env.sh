# Shared settings for the Lightsail scripts. Sourced, not executed.
# Override any of these from the environment.

: "${AWS_PROFILE:=personal}"
: "${AWS_REGION:=us-east-2}"
export AWS_PROFILE AWS_REGION

SERVICE=${SERVICE:-schierer-org}
CONTAINER=site
CERT_NAME=${CERT_NAME:-schierer-org}
HOSTED_ZONE_ID=${HOSTED_ZONE_ID:-ZOB4NXMJR2BZF}
IMAGE=${IMAGE:-localhost/schierer-org:latest}

# Every name the site will ever answer to. A Lightsail certificate cannot be
# changed after creation, so the production names are on it from the start.
CERT_DOMAIN=schierer.org
CERT_SANS="www.schierer.org static.schierer.org"

# Route 53 hosted zone ID for Lightsail container services in us-east-2.
# https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-route-53-alias-record-for-container-service.html
LIGHTSAIL_ALIAS_ZONE_ID=Z10362273VJ548563IY84

ls_() { aws lightsail "$@"; }

service_exists() {
  ls_ get-container-services --service-name "$SERVICE" >/dev/null 2>&1
}

service_url() {
  ls_ get-container-services --service-name "$SERVICE" \
    --query 'containerServices[0].url' --output text
}

# The podman machine socket, so lightsailctl can talk to podman.
use_podman_socket() {
  if [ -z "${DOCKER_HOST:-}" ] && command -v podman >/dev/null; then
    DOCKER_HOST=$(podman machine inspect --format 'unix://{{.ConnectionInfo.PodmanSocket.Path}}')
    export DOCKER_HOST
  fi
}
