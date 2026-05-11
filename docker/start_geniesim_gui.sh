#!/bin/bash
set -euo pipefail

export SIM_REPO_ROOT="${SIM_REPO_ROOT:-/geniesim/main}"
export SIM_ASSETS="${SIM_ASSETS:-${SIM_REPO_ROOT}/source/geniesim/assets}"
export ENABLE_SIM="${ENABLE_SIM:-1}"
export ISAACSIM_HOME="${ISAACSIM_HOME:-/isaac-sim}"
export ROS_DISTRO="${ROS_DISTRO:-jazzy}"
export ROS_VERSION="${ROS_VERSION:-2}"
export ROS_PYTHON_VERSION="${ROS_PYTHON_VERSION:-3}"
export ROS_LOCALHOST_ONLY="${ROS_LOCALHOST_ONLY:-1}"
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}"
export ROS_CMD_DISTRO="${ROS_CMD_DISTRO:-jazzy}"
export DISPLAY="${DISPLAY:-:0}"

ROS_BRIDGE_LIB="${ISAACSIM_HOME}/exts/isaacsim.ros2.bridge/${ROS_DISTRO}/lib"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}${ROS_BRIDGE_LIB}"

if [ -f "${ISAACSIM_HOME}/setup_ros_env.sh" ]; then
    # shellcheck disable=SC1091
    source "${ISAACSIM_HOME}/setup_ros_env.sh"
fi

cd "${SIM_REPO_ROOT}"

default_config=""
for candidate in \
    "source/geniesim/config/organize_items.yaml" \
    "source/geniesim/config/s2r_organize_items.yaml" \
    "source/geniesim/config/config.yaml"; do
    if [ -f "${candidate}" ]; then
        default_config="${candidate}"
        break
    fi
done

config="${default_config}"
extra_args=()
if [ "$#" -gt 0 ]; then
    case "$1" in
        -*)
            extra_args=("$@")
            ;;
        *)
            config="$1"
            shift
            extra_args=("$@")
            ;;
    esac
fi

if [ -z "${config}" ] || [ ! -f "${config}" ]; then
    echo "Genie Sim config not found: ${config:-<none>}"
    echo
    echo "Available configs:"
    find "${SIM_REPO_ROOT}/source/geniesim/config" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) \
        | sed "s#${SIM_REPO_ROOT}/##" | sort
    exit 2
fi

if [ ! -d "${SIM_ASSETS}" ] || [ -z "$(find "${SIM_ASSETS}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
    echo "Warning: SIM_ASSETS=${SIM_ASSETS} is missing or nearly empty."
    echo "The GUI can start, but benchmark scenes may fail until Genie Sim assets are mounted or copied."
fi

echo "Starting Genie Sim GUI"
echo "  DISPLAY=${DISPLAY}"
echo "  SIM_REPO_ROOT=${SIM_REPO_ROOT}"
echo "  SIM_ASSETS=${SIM_ASSETS}"
echo "  Config=${config}"

exec "${ISAACSIM_HOME}/python.sh" "${SIM_REPO_ROOT}/source/geniesim/app/app.py" \
    --config "${config}" \
    "${extra_args[@]}"
