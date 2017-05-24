# !/bin/sh
#
# Vault Helper - Dev Token
#
# This script runs via cron to keep an instance token current
# with the vault server at boot time and on a regular basis.
#
# Usage:
#   sudo sh /opt/vault/helper/dev-auth.sh
#

# Read /etc/vault/unseal_keys
contents=`cat /etc/vault/unseal_keys`

# Prep the output path on tmpfs
outputPath=/var/run/vault
mkdir -p $outputPath

# Use jq to pull out unseal keys (if available)
unsealKeys=`echo $contents | jq -r '.keys[0]'`

# Write the unseal key to well-known location
keyFile=${outputPath}/unseal_key
echo $unsealKeys > $keyFile
chown root:vault-users $keyFile
chmod 0640 $keyFile

# Sealed instances do not appear in Consul, so we use the well-known
# IP address to the vault server.
vaultUrl='https://127.0.0.1:8200'

# Ensure a valid response is received from vault before continuing.
for i in {1..20}
do
    echo "Checking vault seal-status"
    sealResponse=`curl -s $vaultUrl/v1/sys/seal-status`
    sealStatus=`echo $sealResponse | jq .sealed`
    if [ -z "$sealStatus" ]; then
        sleep 1
        continue
    else
        break
    fi
done

# Use unseal keys to unseal vault
# WARNING: This is not a secure practice, but it is only used in dev/test environments
if [ "$sealStatus" = true ]; then
    echo 'Unsealing vault'
    unsealPayload="{\"key\":\"$unsealKeys\"}"
    unsealResponse=`curl -s -X PUT $vaultUrl/v1/sys/unseal -d $unsealPayload`
    unsealStatus=`echo $unsealResponse | jq .sealed`
    if [ "$unsealStatus" != false ]; then
        echo 'Error unsealing vault'
        exit
    fi
    echo "Vault unsealed"
fi

# Use jq to pull out root token
token=`echo $contents | jq -r '.root_token'`

# Write the root token to well-known location
tokenFile=${outputPath}/instance_token
echo $token > $tokenFile

# Only applications that are part of vault-users group
# should be able to access the file.
chown root:vault-users $tokenFile
chmod 0640 $tokenFile
