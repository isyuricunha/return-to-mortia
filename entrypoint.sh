#!/usr/bin/env bash
set -euo pipefail

server_dir="/mnt/server"
steamcmd_dir="${server_dir}/steamcmd"

app_id="${SRCDS_APPID:-3349480}"
windows_install="${WINDOWS_INSTALL:-1}"
auto_update="${AUTO_UPDATE:-1}"
install_flags="${INSTALL_FLAGS:-}"
steam_validate="${STEAM_VALIDATE:-0}"

eos_auth_type="${EOS_AUTH_TYPE:-}"
eos_auth_login="${EOS_AUTH_LOGIN:-}"
eos_auth_password="${EOS_AUTH_PASSWORD:-}"
eos_artifact_name_override="${EOS_ARTIFACT_NAME_OVERRIDE:-}"

server_extra_args_raw="${SERVER_EXTRA_ARGS:-}"

winetricks_run="${WINETRICKS_RUN:-vcrun2022}"
winetricks_force="${WINETRICKS_FORCE:-0}"
export WINEDEBUG="${WINEDEBUG:--all}"
export HOME="${server_dir}"

if [[ -z "${WINEPREFIX:-}" || "${WINEPREFIX}" == "/home/container/.wine" || "${WINEPREFIX}" == "/root/.wine" ]]; then
    export WINEPREFIX="${server_dir}/wineprefix"
fi

xvfb_display="${XVFB_DISPLAY:-:99}"
xvfb_screen="${XVFB_SCREEN:-0}"
xvfb_resolution="${XVFB_RESOLUTION:-1280x1024x24}"
xvfb_pid=""

start_xvfb() {
    export DISPLAY="${xvfb_display}"

    if pgrep -x Xvfb >/dev/null 2>&1; then
        return 0
    fi

    Xvfb "${DISPLAY}" -screen "${xvfb_screen}" "${xvfb_resolution}" -nolisten tcp -ac >/tmp/xvfb.log 2>&1 &
    xvfb_pid=$!

    local display_num="${DISPLAY#:}"
    local sock="/tmp/.X11-unix/X${display_num}"

    for _ in $(seq 1 50); do
        if [[ -S "${sock}" ]]; then
            return 0
        fi
        sleep 0.1
    done

    echo "Xvfb did not become ready; last log:" >&2
    tail -n 200 /tmp/xvfb.log >&2 || true
    return 1
}

cleanup() {
    if [[ -n "${xvfb_pid}" ]]; then
        kill "${xvfb_pid}" >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT

mkdir -p "${server_dir}"

resolve_steam_login() {
    if [[ -z "${STEAM_USER:-}" || -z "${STEAM_PASS:-}" ]]; then
        steam_user="anonymous"
        steam_pass=""
        steam_auth=""
    else
        steam_user="${STEAM_USER}"
        steam_pass="${STEAM_PASS}"
        steam_auth="${STEAM_AUTH:-}"
    fi
}

install_steamcmd() {
    mkdir -p "${steamcmd_dir}"
    curl -sSL -o /tmp/steamcmd.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
    tar -xzvf /tmp/steamcmd.tar.gz -C "${steamcmd_dir}"
    rm -f /tmp/steamcmd.tar.gz

    mkdir -p "${server_dir}/steamapps"
    chmod +x "${steamcmd_dir}/steamcmd.sh"
}

setup_steamclient_libs() {
    mkdir -p "${server_dir}/.steam/sdk32" "${server_dir}/.steam/sdk64"

    if [[ -f "${steamcmd_dir}/linux32/steamclient.so" ]]; then
        cp -f "${steamcmd_dir}/linux32/steamclient.so" "${server_dir}/.steam/sdk32/steamclient.so"
    fi

    if [[ -f "${steamcmd_dir}/linux64/steamclient.so" ]]; then
        cp -f "${steamcmd_dir}/linux64/steamclient.so" "${server_dir}/.steam/sdk64/steamclient.so"
    fi
}

update_server_files() {
    resolve_steam_login

    local validate_flag=""
    if [[ "${steam_validate}" == "1" ]]; then
        validate_flag="validate"
    fi

    local platform_args=()
    if [[ "${windows_install}" == "1" ]]; then
        platform_args+=("+@sSteamCmdForcePlatformType" "windows")
    fi

    "${steamcmd_dir}/steamcmd.sh" \
        +force_install_dir "${server_dir}" \
        +login "${steam_user}" "${steam_pass}" "${steam_auth}" \
        "${platform_args[@]}" \
        +app_update "${app_id}" ${install_flags} ${validate_flag} \
        +quit

    setup_steamclient_libs
}

ensure_winetricks() {
    mkdir -p "${WINEPREFIX}"

    local marker_file="${WINEPREFIX}/.winetricks_installed"
    local marker_state_file="${WINEPREFIX}/.winetricks_installed_state"
    read -r -a desired_verbs_raw <<< "${winetricks_run}"
    desired_verbs=()
    for verb in "${desired_verbs_raw[@]}"; do
        if [[ "${verb}" == "rootcerts" ]]; then
            echo "winetricks verb 'rootcerts' is no longer supported; ignoring it." >&2
            continue
        fi
        if [[ "${verb}" == "ie8_tls12" ]]; then
            echo "winetricks verb 'ie8_tls12' is not supported on win64 prefixes; ignoring it." >&2
            continue
        fi
        desired_verbs+=("${verb}")
    done
    local desired_state="${desired_verbs[*]}"
    local existing_state=""
    if [[ -f "${marker_state_file}" ]]; then
        existing_state="$(cat "${marker_state_file}" 2>/dev/null || true)"
    fi

    if [[ -f "${marker_file}" && "${winetricks_force}" != "1" && "${existing_state}" == "${desired_state}" ]]; then
        return 0
    fi

    start_xvfb
    wineboot -u

    if [[ -n "${winetricks_run}" ]]; then
        if [[ ${#desired_verbs[@]} -gt 0 ]]; then
            winetricks -q "${desired_verbs[@]}"
        fi
    fi

    touch "${marker_file}"
    printf '%s' "${desired_state}" > "${marker_state_file}"
}

ensure_server_config() {
    local config_file="${server_dir}/MoriaServerConfig.ini"

    if [[ ! -f "${config_file}" ]]; then
        cat > "${config_file}" << 'EOF'
[Main]
OptionalPassword=

[World]
Name="Return to Moria Dedicated Server"
OptionalWorldFilename=

[World.Create]
Type=campaign
Seed=random
Difficulty.Preset=normal

[Host]
ListenAddress=
ListenPort=7777
AdvertiseAddress=auto
AdvertisePort=-1
InitialConnectionRetryTime=60
AfterDisconnectionRetryTime=600

[Console]
Enabled=true

[Performance]
ServerFPS=60
LoadedAreaLimit=12
EOF
    fi

    if [[ -n "${WORLD_NAME:-}" ]]; then
        crudini --set "${config_file}" World Name "${WORLD_NAME}"
    fi

    if [[ -n "${SERVER_PASSWORD:-}" ]]; then
        crudini --set "${config_file}" Main OptionalPassword "${SERVER_PASSWORD}"
    fi

    if [[ -n "${DIFFICULTY:-}" ]]; then
        crudini --set "${config_file}" "World.Create" "Difficulty.Preset" "${DIFFICULTY}"
    fi

    if [[ -n "${ADVERTISE_PORT:-}" ]]; then
        crudini --set "${config_file}" Host AdvertisePort "${ADVERTISE_PORT}"
    fi
}

server_exe="${server_dir}/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe"

if [[ ! -x "${steamcmd_dir}/steamcmd.sh" ]]; then
    install_steamcmd
fi

if [[ ! -f "${server_exe}" ]]; then
    steam_validate="1"
    update_server_files
elif [[ "${auto_update}" == "1" ]]; then
    update_server_files
fi

ensure_winetricks
ensure_server_config

cd "${server_dir}"
echo "Starting Return to Moria dedicated server: ${server_exe}"
start_xvfb

server_args=()
if [[ -n "${eos_artifact_name_override}" ]]; then
    server_args+=("-EOSArtifactNameOverride=${eos_artifact_name_override}")
fi

if [[ -n "${server_extra_args_raw}" ]]; then
    read -r -a extra_args <<< "${server_extra_args_raw}"
    server_args+=("${extra_args[@]}")
fi

if [[ -n "${eos_auth_type}" || -n "${eos_auth_login}" || -n "${eos_auth_password}" ]]; then
    if [[ -z "${eos_auth_type}" || -z "${eos_auth_login}" || -z "${eos_auth_password}" ]]; then
        echo "EOS auth env vars provided but incomplete. Need EOS_AUTH_TYPE, EOS_AUTH_LOGIN, EOS_AUTH_PASSWORD." >&2
        exit 1
    fi

    server_args+=("-AUTH_TYPE=${eos_auth_type}")
    server_args+=("-AUTH_LOGIN=${eos_auth_login}")
    server_args+=("-AUTH_PASSWORD=${eos_auth_password}")
fi

exec wine64 "${server_exe}" "${server_args[@]}"
