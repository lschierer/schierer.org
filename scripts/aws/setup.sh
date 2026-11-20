#!/usr/bin/env bash
# One-time (idempotent) setup: the Lightsail container service and its TLS
# certificate, including the DNS validation records in Route 53.
set -euo pipefail
. "$(dirname "$0")/env.sh"

if service_exists; then
  echo "Container service $SERVICE already exists."
else
  echo "Creating container service $SERVICE (nano, 1 node, about \$7/month)..."
  ls_ create-container-service --service-name "$SERVICE" --power nano --scale 1 \
    --tags key=Application,value=schierer.org >/dev/null
fi

if ls_ get-certificates --certificate-name "$CERT_NAME" \
  --query 'certificates[0].certificateName' --output text 2>/dev/null | grep -qx "$CERT_NAME"; then
  echo "Certificate $CERT_NAME already exists."
else
  echo "Requesting certificate $CERT_NAME for $CERT_DOMAIN $CERT_SANS..."
  # shellcheck disable=SC2086
  ls_ create-certificate --certificate-name "$CERT_NAME" \
    --domain-name "$CERT_DOMAIN" --subject-alternative-names $CERT_SANS >/dev/null
fi

cert_status() {
  ls_ get-certificates --certificate-name "$CERT_NAME" --include-certificate-details \
    --query 'certificates[0].certificateDetail.status' --output text
}

if [ "$(cert_status)" != ISSUED ]; then
  echo "Waiting for validation records..."
  records=""
  for _ in $(seq 1 30); do
    records=$(ls_ get-certificates --certificate-name "$CERT_NAME" --include-certificate-details \
      --query 'certificates[0].certificateDetail.domainValidationRecords[].resourceRecord.[name,value]' \
      --output text)
    [ -n "$records" ] && [ "$records" != None ] && break
    sleep 5
  done
  [ -n "$records" ] || { echo "No validation records returned." >&2; exit 1; }

  # Only adds/updates the _xxxx.<name> CNAMEs Lightsail asked for; no other
  # records are touched.
  changes=$(sort -u <<<"$records" | while read -r name value; do
    printf '{"Action":"UPSERT","ResourceRecordSet":{"Name":"%s","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"%s"}]}},' "$name" "$value"
  done)
  aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "{\"Comment\":\"Lightsail cert validation for $CERT_NAME\",\"Changes\":[${changes%,}]}" >/dev/null
  echo "Validation CNAMEs written. Waiting for the certificate to be issued (can take 30+ minutes)..."
  until [ "$(cert_status)" = ISSUED ]; do
    status=$(cert_status)
    case $status in
      FAILED | VALIDATION_TIMED_OUT | REVOKED) echo "Certificate status: $status" >&2; exit 1 ;;
    esac
    sleep 30
  done
fi
echo "Certificate $CERT_NAME is ISSUED."
echo "Next: mise run deploy"
