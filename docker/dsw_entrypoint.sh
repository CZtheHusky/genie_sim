#!/bin/bash
set -e

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

ROS_BRIDGE_LIB="${ISAACSIM_HOME}/exts/isaacsim.ros2.bridge/${ROS_DISTRO}/lib"
case ":${LD_LIBRARY_PATH:-}:" in
    *":${ROS_BRIDGE_LIB}:"*) ;;
    *) export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}${ROS_BRIDGE_LIB}" ;;
esac

if [ -f "${ISAACSIM_HOME}/setup_ros_env.sh" ]; then
    # shellcheck disable=SC1091
    source "${ISAACSIM_HOME}/setup_ros_env.sh"
fi

mkdir -p \
    "${SIM_REPO_ROOT}/output" \
    "${SIM_REPO_ROOT}/source/geniesim/benchmark/saved_task" \
    "${SIM_REPO_ROOT}/source/teleop/app/bin/.cache" \
    "${SIM_REPO_ROOT}/source/teleop/app/bin/logs/dylog" \
    "${SIM_REPO_ROOT}/source/teleop/app/share" \
    "${SIM_ASSETS}" \
    "${HOME}/.vnc"

if ! grep -q "DSW Genie Sim aliases" "${HOME}/.bashrc" 2>/dev/null; then
    cat >>"${HOME}/.bashrc" <<'EOF'

# DSW Genie Sim aliases
export SIM_REPO_ROOT=${SIM_REPO_ROOT:-/geniesim/main}
export SIM_ASSETS=${SIM_ASSETS:-/geniesim/main/source/geniesim/assets}
export ENABLE_SIM=${ENABLE_SIM:-1}
export ISAACSIM_HOME=${ISAACSIM_HOME:-/isaac-sim}
export ROS_DISTRO=${ROS_DISTRO:-jazzy}
export ROS_VERSION=${ROS_VERSION:-2}
export ROS_PYTHON_VERSION=${ROS_PYTHON_VERSION:-3}
export ROS_LOCALHOST_ONLY=${ROS_LOCALHOST_ONLY:-1}
export RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}
export ROS_CMD_DISTRO=${ROS_CMD_DISTRO:-jazzy}
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}${ISAACSIM_HOME}/exts/isaacsim.ros2.bridge/${ROS_DISTRO}/lib
[ -f "${ISAACSIM_HOME}/setup_ros_env.sh" ] && source "${ISAACSIM_HOME}/setup_ros_env.sh"
alias omni_python='${ISAACSIM_HOME}/python.sh'
alias isaacsim='${ISAACSIM_HOME}/runapp.sh'
alias geniesim='${ISAACSIM_HOME}/python.sh /geniesim/main/source/geniesim/app/app.py'
EOF
fi

cd "${SIM_REPO_ROOT}"
exec "$@"
