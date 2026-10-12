#!/usr/bin/env bash
set -euo pipefail
: "${TF_STATE_BUCKET:?Set TF_STATE_BUCKET}"
: "${TF_STATE_KEY:?Set TF_STATE_KEY to the existing state key}"
: "${AWS_REGION:?Set AWS_REGION}"
: "${TF_LOCK_MODE:?Set TF_LOCK_MODE to dynamodb, dual or s3 after coordinating with the team}"
args=(-input=false "-backend-config=bucket=$TF_STATE_BUCKET" "-backend-config=key=$TF_STATE_KEY" "-backend-config=region=$AWS_REGION" "-backend-config=encrypt=true")
case "$TF_LOCK_MODE" in
  dynamodb|dual)
    : "${TF_LOCK_TABLE:?Set TF_LOCK_TABLE}"
    args+=("-backend-config=dynamodb_table=$TF_LOCK_TABLE")
    ;;
  s3) ;;
  *) echo "Invalid TF_LOCK_MODE" >&2; exit 1 ;;
esac
if [[ "$TF_LOCK_MODE" == s3 || "$TF_LOCK_MODE" == dual ]]; then
  args+=("-backend-config=use_lockfile=true")
else
  args+=("-backend-config=use_lockfile=false")
fi
terraform init "${args[@]}"
