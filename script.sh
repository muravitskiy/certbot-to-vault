#!/bin/bash

set -e

CERTS_DIR="/etc/letsencrypt/live"

if [[ -z "${VAULT_ADDR}" ]]; then
    VAULT_ADDR="https://vault.service.consul:8200"
fi

if [[ -z "${VAULT_TOKEN}" ]]; then
    echo "VAULT_TOKEN not set"
    exit 1
fi

if [[ -z "${DOMAINS}" ]]; then
    echo "DOMAINS not set"
    exit 1
fi

if [[ -z "${EMAIL}" ]]; then
    echo "EMAIL not set"
    exit 1
fi

if [[ -z "${VAULT_CERT_PATH}" ]]; then
    VAULT_CERT_PATH="secret/letsencrypt/cert"
fi

if [[ -z "${WEBROOT_PATH}" ]]; then
    WEBROOT_PATH="/webroot"
fi

if [[ ! -d "${WEBROOT_PATH}" ]]; then
    mkdir -p $WEBROOT_PATH
fi

echo "Starting HTTP server"

cd ${WEBROOT_PATH} && python -m SimpleHTTPServer 80 &
PID=$!

sleep 10

CERTBOT_OPTS=""
if [[ ! -z "${CERTBOT_USE_STAGE}" ]]; then
    CERTBOT_OPTS+=" --test-cert"
fi

for DOMAIN in $DOMAINS
do
    echo "Getting certificates for ${DOMAIN}"
    certbot \
        certonly \
        -d ${DOMAIN} \
        --webroot \
        --webroot-path ${WEBROOT_PATH} \
        --noninteractive \
        --email ${EMAIL} \
        --agree-tos \
        $CERTBOT_OPTS
done

echo "Certificates were renewed"
echo "Stopping http server"

kill $PID

echo "Writing certificates to Vault"

CURL_OPTS="--silent --show-error --fail"

if [[ ! -z "${VAULT_SKIP_VERIFY}" ]]; then
    CURL_OPTS+=" --insecure"
fi

for DOMAIN in $DOMAINS
do
    CERT=$(sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' ${CERTS_DIR}/${DOMAIN}/fullchain.pem)
    PRIVATE_KEY=$(sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' ${CERTS_DIR}/${DOMAIN}/privkey.pem)

    if [[ -z "$CERT" || -z "$PRIVATE_KEY" ]]; then
        echo "Certificate for $DOMAIN not found"
        exit 1
    fi


    curl \
        $CURL_OPTS \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "{\"key\":\"$PRIVATE_KEY\", \"cert\": \"$CERT\"}" \
        "$VAULT_ADDR/v1/$VAULT_CERT_PATH/$DOMAIN"
done

echo "Finished"
