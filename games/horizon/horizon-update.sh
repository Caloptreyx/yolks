#!/bin/bash
# Installs or updates Horizon's server (horizon-server) in horizon/ and prepares the game files it reads.
#
# Usage: horizon-update [latest|<tag>]   (default: $HORIZON_VERSION, else latest)
#
# Environment:
#   AUTO_UPDATE         1 (default) asks GitHub for the requested release on every run; 0 only installs
#                       when horizon/ is missing or another release tag was requested
#   PREPARE_GAME_FILES  1 (default) prepares the game files from Mojang's Minecraft client and server
#                       when the installed release has none yet; 0 leaves them to the owner (resources/)
#
# The installed release is recorded in horizon/.horizon-release (tag, then name) and the release the
# game files were prepared for in horizon/.local/horizon-client/.horizon-prepared; nothing is downloaded
# when both match. Preparing takes a few minutes and fits in 1 GB of memory. Worlds and settings
# are never touched. Exit codes: 0 up to date or updated, 1 failure.

set -o pipefail

REPO="horizon-rust/horizon"
ASSET="horizon-server-linux-x86_64.tar.gz"
RELEASE_FILE="horizon/.horizon-release"
PREPARED_FILE="horizon/.local/horizon-client/.horizon-prepared"
# Scratch space on the server's disk: the container /tmp is a small tmpfs.
WORK="${PWD}/.horizon-update"

log() { echo "[horizon-update] $*"; }
fail() { log "$1"; exit 1; }

requested="${1:-${HORIZON_VERSION:-latest}}"
case "${requested,,}" in
    ""|latest|nightly) tag="nightly" ;;
    *) tag="${requested}" ;;
esac
[[ "${tag}" =~ ^[A-Za-z0-9._-]+$ ]] || fail "Invalid Horizon version '${requested}': use latest or a release tag such as v0.2.97."

installed_tag=$(sed -n 1p "${RELEASE_FILE}" 2>/dev/null)
installed_name=$(sed -n 2p "${RELEASE_FILE}" 2>/dev/null)
[[ -x horizon/horizon-server ]] || installed_tag=""

rm -rf "${WORK}"
mkdir -p "${WORK}" || fail "cannot create ${WORK}"
trap 'rm -rf "${WORK}"' EXIT

# Downloads $1 to $2 and checks it against the $3 checksum ($4: sha1sum or sha256sum).
download() {
    curl -fsSL --retry 3 --connect-timeout 15 -o "$2.download" "$1" || return 1
    if ! echo "$3  $2.download" | "$4" -c --quiet - >/dev/null 2>&1; then
        rm -f "$2.download"
        return 1
    fi
    mv -f "$2.download" "$2"
}

# --- horizon-server ---------------------------------------------------------------------------
if [[ "${AUTO_UPDATE:-1}" != "0" || "${installed_tag}" != "${tag}" ]]; then
    release=$(curl -fsSL --retry 3 --connect-timeout 15 -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${REPO}/releases/tags/${tag}") \
        || fail "Could not look up Horizon release '${tag}' (it does not exist, or GitHub's API is unreachable)."
    name=$(jq -r '.name // .tag_name' <<< "${release}")
    name="${name#Horizon }"

    if [[ "${installed_tag}" == "${tag}" && "${installed_name}" == "${name}" ]]; then
        log "Horizon ${name} is up to date."
    else
        url=$(jq -r --arg a "${ASSET}" '.assets[] | select(.name == $a) | .browser_download_url' <<< "${release}")
        digest=$(jq -r --arg a "${ASSET}" '.assets[] | select(.name == $a) | .digest // empty' <<< "${release}")
        [[ -n "${url}" ]] || fail "Horizon release '${tag}' has no ${ASSET}."
        [[ "${digest}" == sha256:* ]] || fail "Horizon release '${tag}' publishes no SHA-256 for ${ASSET}."

        log "Downloading Horizon ${name}..."
        download "${url}" "${WORK}/${ASSET}" "${digest#sha256:}" sha256sum \
            || fail "Could not download Horizon ${name} (download failed or checksum mismatch; Horizon replaces the Nightly's files while it publishes a new one, so try again in a few minutes)."
        mkdir -p "${WORK}/release"
        tar -xzf "${WORK}/${ASSET}" -C "${WORK}/release" || fail "Could not extract ${ASSET}."
        source_dir=$(dirname "$(find "${WORK}/release" -name horizon-server -type f | head -n 1)")
        [[ -x "${source_dir}/horizon-server" && -x "${source_dir}/horizon-engine" ]] || fail "${ASSET} holds no horizon-server."

        # The prepared game files in horizon/.local outlive the release, as in Horizon's own installer.
        [[ -d horizon/.local ]] && mv horizon/.local "${WORK}/local"
        rm -rf horizon
        mv "${source_dir}" horizon
        [[ -d "${WORK}/local" ]] && mv "${WORK}/local" horizon/.local
        printf '%s\n%s\n' "${tag}" "${name}" > "${RELEASE_FILE}"
        log "Installed Horizon ${name}."
    fi
fi
installed_name=$(sed -n 2p "${RELEASE_FILE}")

# --- game files -------------------------------------------------------------------------------
if [[ "${PREPARE_GAME_FILES:-1}" == "0" ]]; then
    exit 0
fi
if [[ "$(cat "${PREPARED_FILE}" 2>/dev/null)" == "${installed_name}" ]]; then
    exit 0
fi

lock=horizon/research-lock.json
mc_version=$(jq -r '.minecraft.version' "${lock}")
manifest_sha1=$(jq -r '.minecraft.manifest_sha1' "${lock}")
java_major=$(jq -r '.minecraft.java_major' "${lock}")
[[ -n "${mc_version}" && "${mc_version}" != null ]] || fail "${lock} names no Minecraft version."
image_java=$(sed -n 's/^JAVA_VERSION="\([0-9]*\).*/\1/p' "${JAVA_HOME}/release" 2>/dev/null)
[[ "${image_java}" == "${java_major}" ]] \
    || fail "Preparing for Horizon ${installed_name} needs Java ${java_major}, but this image has Java ${image_java:-none}: update the image."

log "Preparing the Minecraft ${mc_version} game files (a few minutes)..."
mc="${WORK}/minecraft"
mkdir -p "${mc}/versions/${mc_version}" "${mc}/assets/indexes"

# Mojang's version file, the one Horizon pins.
version_json="${mc}/versions/${mc_version}/${mc_version}.json"
download "https://piston-meta.mojang.com/v1/packages/${manifest_sha1}/${mc_version}.json" "${version_json}" "${manifest_sha1}" sha1sum \
    || fail "Could not download the Minecraft ${mc_version} version file."

download "$(jq -r '.downloads.client.url' "${version_json}")" "${mc}/versions/${mc_version}/${mc_version}.jar" \
    "$(jq -r '.downloads.client.sha1' "${version_json}")" sha1sum \
    || fail "Could not download the Minecraft ${mc_version} client."
download "$(jq -r '.downloads.server.url' "${version_json}")" "${WORK}/server.jar" \
    "$(jq -r '.downloads.server.sha1' "${version_json}")" sha1sum \
    || fail "Could not download the Minecraft ${mc_version} server."

# The client libraries the official launcher installs on Linux (the last matching rule decides).
jq -r '.libraries[]
    | select(.downloads.artifact != null)
    | select((.rules // []) as $r
        | ($r | length) == 0
          or ([$r[] | select((.os.name // "linux") == "linux")] | last | .action) == "allow")
    | .downloads.artifact | "\(.url) \(.path) \(.sha1)"' "${version_json}" > "${WORK}/libraries.txt"
while read -r lib_url lib_path lib_sha1; do
    mkdir -p "$(dirname "${mc}/libraries/${lib_path}")"
    download "${lib_url}" "${mc}/libraries/${lib_path}" "${lib_sha1}" sha1sum \
        || fail "Could not download the library ${lib_path}."
done < "${WORK}/libraries.txt"

# The assets preparing imports: languages, fonts, the built-in packs and the menu panorama.
# Sounds are left out; a server plays none.
index_id=$(jq -r '.assetIndex.id' "${version_json}")
index="${mc}/assets/indexes/${index_id}.json"
download "$(jq -r '.assetIndex.url' "${version_json}")" "${index}" "$(jq -r '.assetIndex.sha1' "${version_json}")" sha1sum \
    || fail "Could not download the Minecraft ${mc_version} asset index."
jq -r '.objects | to_entries[]
    | select(.key == "pack.mcmeta"
        or (.key | startswith("minecraft/lang/"))
        or (.key | startswith("minecraft/font/"))
        or (.key | startswith("minecraft/resourcepacks/"))
        or (.key | startswith("minecraft/textures/gui/title/background/")))
    | .value.hash' "${index}" | sort -u > "${WORK}/assets.txt"
while read -r hash; do
    mkdir -p "${mc}/assets/objects/${hash:0:2}"
    download "https://resources.download.minecraft.net/${hash:0:2}/${hash}" "${mc}/assets/objects/${hash:0:2}/${hash}" "${hash}" sha1sum \
        || fail "Could not download the asset ${hash}."
done < "${WORK}/assets.txt"

# HORIZON_PREPARE_ISOLATED runs one exporter JVM at a time instead of two long-lived 2 GB workers:
# the same files (Horizon checks that the bytes match), and it fits in a 1 GB memory limit.
HORIZON_PREPARE_ISOLATED=1 HOME="${WORK}" \
    ./horizon/horizon-prepare --prepare --root horizon --minecraft-dir "${mc}" --server-jar "${WORK}/server.jar" \
    || fail "horizon-prepare could not prepare the Minecraft ${mc_version} game files (out of memory? It needs about 1 GB)."
# Only the prepared files are read at run time. The imported jars and the exporters' work folders
# are only needed while preparing, which downloads and rebuilds them for the next release.
find horizon/.local -mindepth 1 -maxdepth 1 ! -name horizon-client -exec rm -rf {} +
echo "${installed_name}" > "${PREPARED_FILE}"
log "Prepared the Minecraft ${mc_version} game files for Horizon ${installed_name}."
