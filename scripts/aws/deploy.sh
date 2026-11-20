#!/usr/bin/env bash
# Build the image, push it to the Lightsail container service, deploy it, and
# wait until the new deployment is active and answering.
set -euo pipefail
. "$(dirname "$0")/env.sh"
cd "$(dirname "$0")/../.."

command -v lightsailctl >/dev/null || {
  echo "lightsailctl is required: brew install aws/tap/lightsailctl" >&2
  exit 1
}
service_exists || { echo "Run 'mise run aws-setup' first." >&2; exit 1; }

podman build --platform linux/amd64 -f container/Containerfile -t "$IMAGE" .

use_podman_socket
ls_ push-container-image --service-name "$SERVICE" --label "$CONTAINER" --image "$IMAGE"

image_ref=$(ls_ get-container-images --service-name "$SERVICE" \
  --query 'containerImages[0].image' --output text)
echo "Deploying $image_ref"

ls_ create-container-service-deployment --service-name "$SERVICE" \
  --containers "{\"$CONTAINER\":{\"image\":\"$image_ref\",\"ports\":{\"8080\":\"HTTP\"}}}" \
  --public-endpoint "{\"containerName\":\"$CONTAINER\",\"containerPort\":8080,\"healthCheck\":{\"path\":\"/healthz\",\"successCodes\":\"200\",\"intervalSeconds\":10,\"timeoutSeconds\":5,\"healthyThreshold\":2,\"unhealthyThreshold\":3}}" \
  >/dev/null

echo "Waiting for the deployment to become active..."
sleep 10
while :; do
  read -r state next < <(ls_ get-container-services --service-name "$SERVICE" \
    --query 'containerServices[0].[state,nextDeployment.state]' --output text)
  case "$state/$next" in
    RUNNING/None) break ;;
    */FAILED) echo "Deployment failed; the previous deployment is still serving." >&2; exit 1 ;;
  esac
  sleep 15
done

url=$(service_url)
code=$(curl -s -o /dev/null -w '%{http_code}' "${url}~ann/")
echo "Active at $url (GET /~ann/ -> $code)"
[ "$code" = 200 ]
