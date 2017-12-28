#!/bin/bash

set -eu

if [[ -n "$NO_PROXY" ]]; then
  echo "$OM_IP $OPSMAN_DOMAIN_OR_IP_ADDRESS" >> /etc/hosts
fi

STEMCELL_VERSION=$(
  cat ./pivnet-product/metadata.json |
  jq --raw-output \
    '
    [
      .Dependencies[]
      | select(.Release.Product.Name | contains("Stemcells"))
      | .Release.Version
    ]
    | map(split(".") | map(tonumber))
    | transpose | transpose
    | max // empty
    | map(tostring)
    | join(".")
    '
)

echo "$STEMCELL_VERSION"

if [ -n "$STEMCELL_VERSION" ]; then
  diagnostic_report=$(
    om-linux \
      --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
      --client-id "${OPSMAN_CLIENT_ID}" \
      --client-secret "${OPSMAN_CLIENT_SECRET}" \
      --username "$OPS_MGR_USR" \
      --password "$OPS_MGR_PWD" \
      --skip-ssl-validation \
      curl --silent --path "/api/v0/diagnostic_report"
  )
  echo "$diagnostic_report"
  
  stemcell=$(
    echo $diagnostic_report |
    jq \
      --arg version "$STEMCELL_VERSION" \
      --arg glob "$IAAS" \
    '.stemcells[] | select(contains($version) and contains($glob))'
  )
  
  echo "$stemcell"
  if [[ -z "$stemcell" ]]; then
  
    om-linux -t https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
      --client-id "${OPSMAN_CLIENT_ID}" \
      --client-secret "${OPSMAN_CLIENT_SECRET}" \
      -u "$OPS_MGR_USR" \
      -p "$OPS_MGR_PWD" \
      -k \
      upload-stemcell \
       -s "$FILE_PATH"
  fi
fi
