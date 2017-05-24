# !/bin/bash
#
# Vault Helper - EC2-Auth
# Authenticates an EC2 instance to Hashicorp Vault
#
# This script runs via cron to keep an instance token current
# with the vault server at boot time and on a regular basis.
#
# From:
#   https://gist.github.com/daveadams/be6d4f99671289f374ad0af71a4424b0
#
# Usage:
#   sudo sh /opt/vault/helper/ec2-auth.sh
#

# configuration stored in environment variables in /etc/vault/client.conf
# expected configuration (defaults are selected below if none is specified):
#   VAULT_ADDR = url of vault server
#   VAULT_ROLE = role name to authenticate as
if [[ -e /etc/vault/client.conf ]]; then
    source /etc/vault/client.conf
fi

vault_addr="${VAULT_ADDR:-http://127.0.0.1:8200}"

die() { echo "ERROR: $@" >&2; exit 1; }

[[ $( id -u ) == 0 ]] \
    || die "You must be root to authenticate this instance"

# Prep the output path on tmpfs
outputPath=/var/run/vault
mkdir -p $outputPath

# fetch signed identity document, AMI ID, and IAM profile name from meta-data service
pkcs7=$( curl -Ss http://169.254.169.254/latest/dynamic/instance-identity/pkcs7 |paste -s -d '' )
ami=$( curl -Ss http://169.254.169.254/latest/meta-data/ami-id )
iam_profile=$( curl -s http://169.254.169.254/latest/meta-data/iam/info |jq -r .InstanceProfileArn |cut -d/ -f2- )

# generate a new nonce unless one already exists
nonce_file=/etc/vault/ec2_auth_nonce
nonce=
if [[ -e $nonce_file ]]; then
    nonce=$( <"$nonce_file" )
else
    nonce=$( openssl rand -base64 36 )
fi

# prefer VAULT_ROLE, then instance profile name, then AMI ID
role_name="${VAULT_ROLE:-${iam_profile:-${ami}}}"

result=$(
    curl -Ss -XPOST "${vault_addr}/v1/auth/aws-ec2/login" \
        -d '{"role":"'"$role_name"'","pkcs7":"'"$pkcs7"'","nonce":"'"$nonce"'"}"'
)

token=$( jq -r .auth.client_token <<< "$result" )
accessor=$( jq -r .auth.accessor <<< "$result" )

if [[ -z $token ]] || [[ $token == null ]]; then
    jq . <<< "$result" >&2
    die "Could not authenticate"
fi

# write nonce to disk if it didn't already exist
if [[ ! -e $nonce_file ]]; then
    mkdir -p "$( dirname "$nonce_file" )"
    touch "$nonce_file"
    chown root:root "$nonce_file"
    chmod 0600 "$nonce_file"
    echo "$nonce" > "$nonce_file"
    chmod 0400 "$nonce_file"
fi

# write token to tmpfs, readable only to vault-users group
token_file=${outputPath}/instance_token
touch $token_file
chown root:vault-users $token_file
chmod 0640 $token_file
echo "$token" > $token_file

# write token accessor to tmpfs, world readable is ok
accessor_file=${outputPath}/token_accessor
echo "$accessor" > $accessor_file
chmod 0644 $accessor_file
