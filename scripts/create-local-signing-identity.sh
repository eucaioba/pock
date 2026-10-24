#!/bin/bash
# Creates a self-signed code signing identity in the login keychain.
# Signing every local build with the same certificate keeps Pock's designated
# requirement stable, so Accessibility and Automation permissions survive rebuilds.
# Ad hoc signatures are identified by cdhash, which changes on every build.
set -euo pipefail
name="${POCK_SIGN_IDENTITY:-Pock Local Signing}"
keychain="$HOME/Library/Keychains/login.keychain-db"
if security find-certificate -c "$name" "$keychain" >/dev/null 2>&1; then
  echo "Identity \"$name\" already exists."
  exit 0
fi
work="$(mktemp -d /private/tmp/pock-identity.XXXXXX)"
trap 'rm -rf "$work"' EXIT
cat > "$work/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $name
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$work/openssl.cnf" \
  -keyout "$work/key.pem" -out "$work/cert.pem" 2>/dev/null
password="$(uuidgen)"
/usr/bin/openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" -name "$name" \
  -out "$work/identity.p12" -passout "pass:$password"
# Only codesign may use the private key without asking.
security import "$work/identity.p12" -k "$keychain" -P "$password" -T /usr/bin/codesign
echo "Created \"$name\". Reinstall Pock with: bash scripts/install-local.sh"
