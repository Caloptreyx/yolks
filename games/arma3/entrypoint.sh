#!/bin/bash
# Arma 3 dedicated server entrypoint for Caloptreyx/yolks (MIT License).
# Follows games/dayz/entrypoint.sh, which is based on the DayZ image by David Wolfe (Red-Thirten), MIT License.
#
# Updates the server and its Steam Workshop mods, starts the Headless Clients, then runs the panel's
# startup command through eval, with {{VAR}} replaced by ${VAR}. The startup command can use:
#   CLIENT_MODS   Additional Mods plus the Arma 3 Launcher modlist, as "@123;mymod;" (for -mod=)
#   SERVER_MODS   Server-Side Mods, as "@123;mymod;" (for -serverMod=)
#
# Environment (set by the egg):
#   SERVER_BINARY, SERVER_PORT, SERVER_PASSWORD
#   STEAM_USER, STEAM_PASS             Steam login; anonymous cannot download Arma 3. Removed before the server starts.
#   STEAMCMD_APPID, STEAMCMD_BETAID    Server app (233780) and branch (public, creatordlc, profiling, ...)
#   UPDATE_SERVER=1                    Update the server and all Workshop mods on start
#   VALIDATE_SERVER=1                  Validate the server files during the update
#   DISABLE_MOD_UPDATES=1              Never download Workshop mods
#   STEAMCMD_ATTEMPTS                  Attempts per SteamCMD download (default 3)
#   MOD_FILE                           Modlist exported from the Arma 3 Launcher (HTML)
#   MODIFICATIONS, SERVERMODS          Semicolon-separated mod folders; @<workshopID> entries are downloaded
#   OPTIONALMODS                       Semicolon-separated @<workshopID> mods whose keys are installed, but not loaded
#   MODS_LOWERCASE=1                   Rename the files of every loaded mod to lowercase
#   HC_NUM, HC_HIDE=1                  Headless Clients to start (0-5), and whether to hide their output

GAME_ID=107410                                  # Arma 3 game app, owner of the Workshop items
STEAMCMD=./steamcmd/steamcmd.sh
STEAMCMD_LOG=/tmp/steamcmd.log
WORKSHOP_STATE=./Steam/workshop-versions        # time_updated of each downloaded Workshop mod
WORKSHOP_API=https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/
STEAMCMD_ATTEMPTS=${STEAMCMD_ATTEMPTS:-3}

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[$1]${NC} $2"; }
warn() { echo -e "${YELLOW}[$1] $2${NC}"; }
fatal() {
    echo -e "\n${RED}[ERROR] $1${NC}\n"
    exit 1
}

# Prints the entries of a semicolon-separated list one per line, trimmed, without empty entries.
split_mods() {
    tr ';' '\n' <<< "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$'
}

# Joins lines into "a;b;", keeping the first occurrence of each, in order (load order matters).
join_mods() {
    awk 'NF && !seen[$0]++ { printf "%s;", $0 }'
}

# Renames everything inside a directory to lowercase, as the Linux server needs. The directory keeps its name.
lowercase() {
    local src dst
    find "$1" -mindepth 1 -depth -name '*[[:upper:]]*' -print0 | while IFS= read -r -d '' src; do
        dst="$(dirname "${src}")/$(basename "${src}" | tr '[:upper:]' '[:lower:]')"
        [[ -e "${dst}" ]] || mv -T "${src}" "${dst}"
    done
}

# run_steamcmd <success text> <steamcmd commands...>
# Retries up to STEAMCMD_ATTEMPTS times; returns 1 when no attempt printed the success text.
# Exits on errors a retry cannot fix. stdin is closed so a Steam Guard prompt fails instead of hanging.
run_steamcmd() {
    local success=$1 attempt
    shift
    for (( attempt = 1; attempt <= STEAMCMD_ATTEMPTS; attempt++ )); do
        if (( attempt > 1 )); then
            warn UPDATE "Retrying in 5 seconds (attempt ${attempt} of ${STEAMCMD_ATTEMPTS})..."
            sleep 5
        fi
        "${STEAMCMD}" "$@" +quit < /dev/null 2>&1 | tee "${STEAMCMD_LOG}"
        grep -qF -- "${success}" "${STEAMCMD_LOG}" && return 0

        if grep -qE "Logging in user .*(FAILED|ERROR)|Login Failure|Invalid Password|Two-factor|Account Logon Denied|Steam Guard code" "${STEAMCMD_LOG}"; then
            fatal "Steam login failed. The [Host] Steam Username/Password are wrong, Steam Guard is on, or Steam is rate limiting the account. Contact your host."
        fi
        if grep -qE "state is 0x(202|212)" "${STEAMCMD_LOG}"; then
            fatal "Not enough disk space to download the update."
        fi
    done
    return 1
}

# Prints "<id> <time_updated>" for each public Workshop item, in one request.
workshop_details() {
    local args=(-d "itemcount=$#") i=0 id
    for id in "$@"; do
        args+=(-d "publishedfileids[${i}]=${id}")
        i=$((i + 1))
    done
    curl -fsS --max-time 30 --retry 2 "${args[@]}" "${WORKSHOP_API}" \
        | jq -r '.response.publishedfiledetails[]? | select(.result == 1) | "\(.publishedfileid) \(.time_updated)"'
}

# install_mod <id> <regular|optional> <downloaded folder>
install_mod() {
    local id=$1 type=$2 src=$3 key
    mkdir -p keys
    if [[ ${type} == optional ]]; then
        # Optional mods only need their keys; the files are removed to save space.
        rm -f "keys/optional_${id}_"*
        while IFS= read -r -d '' key; do
            cp -f "${key}" "keys/optional_${id}_$(basename "${key}" | tr '[:upper:]' '[:lower:]')"
        done < <(find "${src}" -type f -iname '*.bikey' -print0)
        rm -rf "${src}"
    else
        # A hard-link copy can be renamed to lowercase without touching SteamCMD's files, so later
        # updates only download what changed. Falls back to a real copy across filesystems.
        rm -rf "@${id}"
        cp -al "${src}" "@${id}" 2>/dev/null || { rm -rf "@${id}"; cp -a "${src}" "@${id}"; }
        lowercase "@${id}"
        find "@${id}" -type f -iname '*.bikey' -exec cp -f -t keys {} +
    fi
}

## === START ===

sleep 1
cd /home/container || exit 1

export TZ="${TZ:-UTC}"
INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')
export INTERNAL_IP

## Mod lists
client_list=$(split_mods "${MODIFICATIONS}")
if [[ -n "${MOD_FILE}" ]]; then
    if [[ -f "${MOD_FILE}" ]] && grep -q 'Created by Arma 3 Launcher' "${MOD_FILE}"; then
        client_list+=$'\n'$(grep -o 'filedetails/?id=[0-9]\+' "${MOD_FILE}" | cut -d= -f2 | sed 's/^/@/')
    else
        warn STARTUP "Modlist file \"${MOD_FILE}\" is missing or was not exported from the Arma 3 Launcher; it is ignored."
    fi
fi
CLIENT_MODS=$(join_mods <<< "${client_list}")
SERVER_MODS=$(split_mods "${SERVERMODS}" | join_mods)
export CLIENT_MODS SERVER_MODS

# Workshop mods: regular ones are loaded, optional ones (only in OPTIONALMODS) just get their keys installed.
declare -A mod_type=()
mod_ids=()
while IFS= read -r mod; do
    if [[ ${mod} =~ ^@([0-9]+)$ ]] && [[ -z ${mod_type[${BASH_REMATCH[1]}]} ]]; then
        mod_type[${BASH_REMATCH[1]}]=regular
        mod_ids+=("${BASH_REMATCH[1]}")
    fi
done < <(split_mods "${CLIENT_MODS}${SERVER_MODS}")
while IFS= read -r mod; do
    if [[ ${mod} =~ ^@([0-9]+)$ ]]; then
        if [[ -z ${mod_type[${BASH_REMATCH[1]}]} ]]; then
            mod_type[${BASH_REMATCH[1]}]=optional
            mod_ids+=("${BASH_REMATCH[1]}")
        fi
    else
        warn STARTUP "Optional mod \"${mod}\" is not in @<workshopID> form; it is ignored."
    fi
done < <(split_mods "${OPTIONALMODS}")

## Server update
steamcmd_ok=1
if [[ ! -x ${STEAMCMD} ]]; then
    steamcmd_ok=0
    warn UPDATE "SteamCMD is missing from the server files, so nothing is updated. Reinstall the server to restore it."
fi
if [[ ${UPDATE_SERVER} == 1 && ${steamcmd_ok} == 1 ]]; then
    beta=()
    [[ -n ${STEAMCMD_BETAID} ]] && beta=(-beta "${STEAMCMD_BETAID}")
    # Public password of the profiling branch, from the Bohemia Interactive wiki.
    [[ ${STEAMCMD_BETAID} == profiling ]] && beta+=(-betapassword CautionSpecialProfilingAndTestingBranchArma3)
    validate=()
    [[ ${VALIDATE_SERVER} == 1 ]] && validate=(validate)
    info UPDATE "Updating the server (app ${STEAMCMD_APPID}, branch ${STEAMCMD_BETAID:-public})..."
    if run_steamcmd "Success! App '${STEAMCMD_APPID}'" +force_install_dir /home/container \
        "+login \"${STEAM_USER}\" \"${STEAM_PASS}\"" +app_update "${STEAMCMD_APPID}" "${beta[@]}" "${validate[@]}"; then
        info UPDATE "The server is up to date."
    else
        warn UPDATE "The server could not be updated; starting the installed version."
    fi
fi

## Workshop mods
# With Automatic Updates on, every mod is checked against its Workshop update time. Otherwise only
# mods that are not downloaded yet are fetched.
if (( ${#mod_ids[@]} > 0 )) && [[ ${DISABLE_MOD_UPDATES} != 1 && ${steamcmd_ok} == 1 ]]; then
    info UPDATE "Checking ${#mod_ids[@]} Steam Workshop mod(s)..."
    mkdir -p "${WORKSHOP_STATE}"
    declare -A latest=()
    if [[ ${UPDATE_SERVER} == 1 ]]; then
        while read -r id updated; do
            latest[${id}]=${updated}
        done < <(workshop_details "${mod_ids[@]}")
        (( ${#latest[@]} > 0 )) || warn UPDATE "The Steam Workshop API did not answer; only missing mods are downloaded."
    fi

    for id in "${mod_ids[@]}"; do
        installed=$(cat "${WORKSHOP_STATE}/${id}" 2>/dev/null)
        if [[ ${mod_type[${id}]} == regular && ! -d "@${id}" ]] || [[ -z ${installed} ]]; then
            info UPDATE "Downloading mod ${CYAN}${id}${NC}..."
        elif [[ -n ${latest[${id}]} && ${latest[${id}]} != "${installed}" ]]; then
            info UPDATE "Updating mod ${CYAN}${id}${NC} (Workshop update $(date -u -d "@${latest[${id}]}" '+%Y-%m-%d %H:%M UTC'))..."
        else
            continue
        fi

        if ! run_steamcmd "Success. Downloaded item ${id}" "+login \"${STEAM_USER}\" \"${STEAM_PASS}\"" \
            +workshop_download_item "${GAME_ID}" "${id}"; then
            warn UPDATE "Mod ${id} could not be downloaded; the host's Steam account must own Arma 3. Skipping it."
            continue
        fi
        src=$(sed -n "s/.*Success\. Downloaded item ${id} to \"\(.*\)\" (.*/\1/p" "${STEAMCMD_LOG}" | tail -n 1)
        [[ -d "${src}" ]] || src="${HOME}/Steam/steamapps/workshop/content/${GAME_ID}/${id}"
        install_mod "${id}" "${mod_type[${id}]}" "${src}"
        echo "${latest[${id}]:-unknown}" > "${WORKSHOP_STATE}/${id}"
        info UPDATE "Mod ${id} installed."
    done
fi

# Keys of optional mods that are no longer configured.
for key in keys/optional_*; do
    [[ -e ${key} ]] || continue
    id=${key#keys/optional_}
    id=${id%%_*}
    if [[ ${mod_type[${id}]} != optional ]]; then
        rm -f "${key}"
        [[ -z ${mod_type[${id}]} ]] && rm -f "${WORKSHOP_STATE}/${id}"
    fi
done

if [[ ${MODS_LOWERCASE} == 1 ]]; then
    while IFS= read -r mod; do
        if [[ -d ${mod} ]]; then
            info STARTUP "Renaming the files of ${mod} to lowercase..."
            lowercase "${mod}"
        fi
    done < <(split_mods "${CLIENT_MODS}${SERVER_MODS}")
fi

if [[ ! -f "./${SERVER_BINARY}" ]]; then
    fatal "The server binary ${SERVER_BINARY} is missing. Turn on Automatic Updates or reinstall the server."
fi

# Network tuning file passed with -cfg; the server misbehaves without it.
if [[ ! -f basic.cfg ]]; then
    info STARTUP "Creating the default basic.cfg..."
    cat > basic.cfg << 'EOF'
// Network tuning, see https://community.bistudio.com/wiki/Arma_3:_Basic_Server_Config_File
// Bandwidth the server is guaranteed to have and can never exceed (bits per second).
MinBandwidth = 131072;
MaxBandwidth = 10000000000;
// Packets per frame and payload sizes (bytes).
MaxMsgSend = 128;
MaxSizeGuaranteed = 512;
MaxSizeNonguaranteed = 256;
// Minimal error before network updates are sent for far and near units.
MinErrorToSend = 0.001;
MinErrorToSendNear = 0.01;
// Largest custom face or sound file players may upload (bytes); 0 disables them.
MaxCustomFileSize = 0;
class sockets { maxPacketSize = 1400; };
EOF
fi

# The server needs its UID to resolve to a user with a home directory; Wings runs containers with
# arbitrary UIDs. The 32-bit binaries need the 32-bit wrapper.
export USER_ID GROUP_ID
USER_ID=$(id -u)
GROUP_ID=$(id -g)
envsubst < /passwd.template > "${NSS_WRAPPER_PASSWD}"
printf 'root:x:0:\n%s:x:%s:\n' "${USER}" "${GROUP_ID}" > "${NSS_WRAPPER_GROUP}"
if [[ ${SERVER_BINARY} == *x64* ]]; then
    export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libnss_wrapper.so
else
    export LD_PRELOAD=/usr/lib/i386-linux-gnu/libnss_wrapper.so
fi

unset STEAM_USER STEAM_PASS

## Headless Clients
hc_started=0
if [[ ${HC_NUM} =~ ^[1-9][0-9]*$ ]]; then
    info STARTUP "Starting ${HC_NUM} Headless Client(s)..."
    for (( i = 1; i <= HC_NUM; i++ )); do
        hc=("./${SERVER_BINARY}" -client -connect=127.0.0.1 "-port=${SERVER_PORT}" "-name=hc${i}" "-mod=${CLIENT_MODS}")
        [[ -n ${SERVER_PASSWORD} ]] && hc+=("-password=${SERVER_PASSWORD}")
        if [[ ${HC_HIDE} == 1 ]]; then
            "${hc[@]}" > /dev/null 2>&1 &
        else
            "${hc[@]}" 2>&1 | sed -u "s/^/[HC${i}] /" &
        fi
        hc_started=1
    done
fi

## Server
info STARTUP "Mods: ${CLIENT_MODS:-none}  Server-side mods: ${SERVER_MODS:-none}"
MODIFIED_STARTUP=$(printf '%s' "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo -e "\n${CYAN}:/home/container\$ ${MODIFIED_STARTUP}${NC}\n"
eval "${MODIFIED_STARTUP}"
exit_code=$?

# Headless Clients would keep the container running after the server stops.
if (( hc_started )); then
    pkill -P $$ 2>/dev/null
    wait 2>/dev/null
fi

if [[ ${exit_code} -ne 0 && ${exit_code} -ne 130 ]]; then
    echo -e "\n${RED}[ERROR] The server exited with code ${exit_code}.${NC}\n"
    exit 1
fi
