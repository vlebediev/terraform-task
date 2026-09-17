#!/bin/bash
set -e

TOKEN="$(curl -sX PUT --max-time 2 "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300" 2>/dev/null || true)"
REGION="${AWS_REGION:-$(curl -s --max-time 2 -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)}"

P=/vlebediev/wordpress
echo "Region resolved: ${REGION}"

# Wait for DB credentials to appear in SSM (RDS may still be provisioning).
echo "Waiting for DB credentials in SSM..."
for i in $(seq 1 60); do
  if aws ssm get-parameter --region "$REGION" --name "$P/db_host" \
       --query 'Parameter.Value' --output text >/dev/null 2>&1; then
    echo "DB credentials found in SSM (attempt $i)."
    break
  fi
  echo "  not ready yet (attempt $i/60), retrying in 10s..."
  sleep 10
done

echo "Fetching DB credentials from SSM Parameter Store..."
export WORDPRESS_DB_HOST="$(aws ssm get-parameter --region $REGION --name $P/db_host --query 'Parameter.Value' --output text)"
export WORDPRESS_DB_NAME="$(aws ssm get-parameter --region $REGION --name $P/db_name --query 'Parameter.Value' --output text)"
export WORDPRESS_DB_USER="$(aws ssm get-parameter --region $REGION --name $P/db_user --query 'Parameter.Value' --output text)"
export WORDPRESS_DB_PASSWORD="$(aws ssm get-parameter --region $REGION --name $P/db_password --with-decryption --query 'Parameter.Value' --output text)"

echo "DB host resolved: ${WORDPRESS_DB_HOST}"

exec docker-entrypoint.sh "$@"
