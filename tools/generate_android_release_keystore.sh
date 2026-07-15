#!/usr/bin/env bash
# Create Ultravibe Android upload keystore (once). Back up .secrets/ offline.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS="$ROOT/.secrets"
KEYSTORE="$SECRETS/ultravibe-release.keystore"
ENV_FILE="$SECRETS/android-release-signing.env"
ALIAS="ultravibe"

# shellcheck source=/dev/null
source "$ROOT/tools/setup_android_build_env.sh"

mkdir -p "$SECRETS"
chmod 700 "$SECRETS"

if [[ -f "$KEYSTORE" ]]; then
	echo "Keystore already exists: $KEYSTORE" >&2
	echo "Delete it first if you really want a new one." >&2
	exit 1
fi

PASS="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"

keytool -genkeypair -v \
	-keystore "$KEYSTORE" \
	-alias "$ALIAS" \
	-keyalg RSA -keysize 2048 -validity 10000 \
	-storepass "$PASS" -keypass "$PASS" \
	-dname "CN=Ultravibe, OU=Gnosis Games, O=Gnosis Games, L=Athens, ST=Attica, C=GR"

chmod 600 "$KEYSTORE"

cat > "$ENV_FILE" <<EOF
# Ultravibe Android release signing — BACK UP OFFLINE. Never commit.
KEYSTORE_PATH="$KEYSTORE"
KEYSTORE_ALIAS="$ALIAS"
KEYSTORE_PASSWORD="$PASS"
EOF
chmod 600 "$ENV_FILE"

echo "Created release keystore:"
echo "  $KEYSTORE"
echo "  $ENV_FILE  (alias + password)"
echo ""
echo "Back up both files to a password manager or encrypted drive."
echo "Then run: ./tools/export_android_aab.sh"
