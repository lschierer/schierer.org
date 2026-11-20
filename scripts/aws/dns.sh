#!/usr/bin/env bash
# Point one or more hostnames at the container service:
#   1. attach them (with the certificate) to the service as custom domains
#   2. UPSERT a Route 53 alias A record for each one
#
#   scripts/aws/dns.sh static.schierer.org
#   scripts/aws/dns.sh schierer.org www.schierer.org   # production cutover
#
# UPSERT replaces whatever record of that name exists, so the production
# names require CONFIRM_CUTOVER=yes.
set -euo pipefail
. "$(dirname "$0")/env.sh"

[ $# -gt 0 ] || { echo "usage: $0 hostname..." >&2; exit 1; }
for name in "$@"; do
  case $name in
    schierer.org | www.schierer.org)
      [ "${CONFIRM_CUTOVER:-}" = yes ] || {
        echo "$name is a production name; set CONFIRM_CUTOVER=yes to replace its DNS record." >&2
        exit 1
      } ;;
  esac
done

# Keep names already attached, add the new ones.
attached=$(ls_ get-container-services --service-name "$SERVICE" \
  --query "containerServices[0].publicDomainNames.\"$CERT_NAME\"[]" --output text)
[ "$attached" = None ] && attached=""
all=$(printf '%s\n' $attached "$@" | sort -u | grep -v '^$')
json_names=$(printf '"%s",' $all)
ls_ update-container-service --service-name "$SERVICE" \
  --public-domain-names "{\"$CERT_NAME\":[${json_names%,}]}" >/dev/null
echo "Attached to $SERVICE: $(echo $all)"

target=$(service_url | sed -e 's|^https://||' -e 's|/$||')
changes=""
for name in "$@"; do
  changes+=$(printf '{"Action":"UPSERT","ResourceRecordSet":{"Name":"%s.","Type":"A","AliasTarget":{"HostedZoneId":"%s","DNSName":"%s.","EvaluateTargetHealth":true}}},' \
    "$name" "$LIGHTSAIL_ALIAS_ZONE_ID" "$target")
done
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "{\"Comment\":\"Point at Lightsail $SERVICE\",\"Changes\":[${changes%,}]}" >/dev/null
echo "Alias records written for: $*"
