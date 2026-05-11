#!/bin/bash
set -euo pipefail

export VNC_DISPLAY="${VNC_DISPLAY:-:0}"
export VNC_GEOMETRY="${VNC_GEOMETRY:-1280x720}"
export VNC_DEPTH="${VNC_DEPTH:-24}"
export VNC_PASSWORD="${VNC_PASSWORD:-geniesim}"

display_number="${VNC_DISPLAY#:}"
vnc_port=$((5900 + display_number))
novnc_port="${NOVNC_PORT:-6080}"
turbovnc_bin="${TURBOVNC_BIN:-/opt/TurboVNC/bin}"
vncserver="${turbovnc_bin}/vncserver"
vncpasswd="${turbovnc_bin}/vncpasswd"

if [ ! -x "${vncserver}" ] || [ ! -x "${vncpasswd}" ]; then
    echo "TurboVNC is not installed at ${turbovnc_bin}."
    echo "Rebuild the DSW image with Dockerfile.dsw."
    exit 1
fi

mkdir -p "${HOME}/.vnc"
printf "%s\n" "${VNC_PASSWORD}" | "${vncpasswd}" -f >"${HOME}/.vnc/passwd"
chmod 600 "${HOME}/.vnc/passwd"

cat >"${HOME}/.vnc/xstartup" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XKL_XMODMAP_DISABLE=1
[ -r "$HOME/.Xresources" ] && xrdb "$HOME/.Xresources"
xset s off
/usr/bin/startxfce4
EOF
chmod +x "${HOME}/.vnc/xstartup"

if "${vncserver}" -list 2>/dev/null | awk '{print $1}' | grep -qx "${VNC_DISPLAY}"; then
    echo "VNC display ${VNC_DISPLAY} is already running. Restarting it for a clean XFCE session."
    "${vncserver}" -kill "${VNC_DISPLAY}" >/dev/null 2>&1 || true
fi

"${vncserver}" "${VNC_DISPLAY}" -geometry "${VNC_GEOMETRY}" -depth "${VNC_DEPTH}" -localhost no

if pgrep -f "websockify.*:${novnc_port}.*localhost:${vnc_port}" >/dev/null 2>&1; then
    echo "noVNC/websockify is already forwarding ${novnc_port} -> ${vnc_port}."
else
    novnc_dir="/usr/share/novnc"
    if [ ! -d "${novnc_dir}" ]; then
        novnc_dir="/usr/share/noVNC"
    fi
    websockify --web="${novnc_dir}" "0.0.0.0:${novnc_port}" "localhost:${vnc_port}" \
        >"${HOME}/.vnc/novnc-${novnc_port}.log" 2>&1 &
fi

cat <<EOF

TurboVNC is running on display ${VNC_DISPLAY} (${VNC_GEOMETRY}, depth ${VNC_DEPTH}).
TurboVNC port: ${vnc_port}
noVNC port:   ${novnc_port}

In Aliyun DSW, expose ${novnc_port} as a Custom Service / Web Service port,
then open the generated DSW service URL in your browser.

Default VNC password: ${VNC_PASSWORD}
Override it with:     export VNC_PASSWORD='your-password'

Use this display for Genie Sim GUI:
  export DISPLAY=${VNC_DISPLAY}
  start_geniesim_gui.sh

EOF
