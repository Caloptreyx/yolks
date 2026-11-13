#!/bin/bash
# Installs or updates the Minecraft Bedrock Dedicated Server in the current directory.
#
# Usage: bedrock-update [latest|preview|<version>]   (default: $BEDROCK_VERSION, else latest)
#
# The installed version is recorded in .bedrock-version; nothing is downloaded when it already
# matches. server.properties, permissions.json and allowlist.json are kept once they exist, and
# worlds are never touched. Exit codes: 0 up to date or updated, 1 failure.

set -o pipefail

LINKS_API="https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"
# minecraft.net drops requests without a browser user agent.
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"
KEEP_FILES=(server.properties permissions.json allowlist.json)

requested="${1:-${BEDROCK_VERSION:-latest}}"
requested="${requested,,}"

case "${requested}" in
    latest|preview)
        type="serverBedrockLinux"
        [[ "${requested}" == "preview" ]] && type="serverBedrockPreviewLinux"
        url=$(curl -fsSL -A "${USER_AGENT}" --max-time 30 "${LINKS_API}" \
            | jq -r --arg t "${type}" '.result.links[] | select(.downloadType == $t) | .downloadUrl')
        if [[ -z "${url}" || "${url}" == "null" ]]; then
            echo "[bedrock-update] Could not look up the ${requested} Bedrock server version."
            exit 1
        fi
        ;;
    *)
        if [[ ! "${requested}" =~ ^[0-9]+(\.[0-9]+){2,3}$ ]]; then
            echo "[bedrock-update] Invalid version '${requested}': use latest, preview or a version like 1.21.50.10."
            exit 1
        fi
        url="https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-${requested}.zip"
        ;;
esac

version="${url##*/bedrock-server-}"
version="${version%.zip}"
installed=$(cat .bedrock-version 2>/dev/null)

if [[ "${installed}" == "${version}" && -x bedrock_server ]]; then
    echo "[bedrock-update] Bedrock server ${version} is up to date."
    exit 0
fi

echo "[bedrock-update] Installing Bedrock server ${version}${installed:+ (was ${installed})}..."

# Downloaded next to the server: the container /tmp is a small tmpfs.
archive=".bedrock-server-${version}.zip"
if ! curl -fsSL -A "${USER_AGENT}" --retry 3 -o "${archive}" "${url}"; then
    rm -f "${archive}"
    echo "[bedrock-update] Download failed: ${url}"
    exit 1
fi

exclude=()
for file in "${KEEP_FILES[@]}"; do
    [[ -e "${file}" ]] && exclude+=("${file}")
done

unzip_args=(-q -o "${archive}")
(( ${#exclude[@]} > 0 )) && unzip_args+=(-x "${exclude[@]}")

if ! unzip "${unzip_args[@]}"; then
    rm -f "${archive}"
    echo "[bedrock-update] Could not extract ${archive}."
    exit 1
fi
rm -f "${archive}"
chmod +x bedrock_server
echo "${version}" > .bedrock-version

echo "[bedrock-update] Bedrock server ${version} installed.${exclude[*]:+ Kept: ${exclude[*]}.}"
