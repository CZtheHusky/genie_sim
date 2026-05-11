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

ROS_BRIDGE_LIB="${ISAACSIM_HOME}/exts/isaacsim.ros2.bridge/${ROS_DISTRO}/lib"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}${ROS_BRIDGE_LIB}"

if [ -f "${ISAACSIM_HOME}/setup_ros_env.sh" ]; then
    # shellcheck disable=SC1091
    source "${ISAACSIM_HOME}/setup_ros_env.sh"
fi

cd "${SIM_REPO_ROOT}"

echo "Genie Sim headless environment check"
echo "  SIM_REPO_ROOT=${SIM_REPO_ROOT}"
echo "  SIM_ASSETS=${SIM_ASSETS}"
echo "  ISAACSIM_HOME=${ISAACSIM_HOME}"
echo "  ROS_DISTRO=${ROS_DISTRO}"
echo "  RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION}"
echo "  ROS bridge lib=${ROS_BRIDGE_LIB}"
echo

echo "GPU:"
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi -L || true
else
    echo "  nvidia-smi not found"
fi
echo

echo "Isaac Sim Python:"
"${ISAACSIM_HOME}/python.sh" --version
echo

echo "Python import check:"
"${ISAACSIM_HOME}/python.sh" - <<'PY'
import os
import geniesim
import geniesim.utils.system_utils as system_utils

print("  geniesim package:", getattr(geniesim, "__file__", "<namespace>"))
print("  config path:", system_utils.config_path())
print("  assets path:", system_utils.assets_path())
print("  SIM_ASSETS:", os.environ.get("SIM_ASSETS"))
PY

cat <<'EOF'

Headless check complete.
For a later replay dry-run, add a dedicated replay entrypoint here instead of
controlling the real robot. This script intentionally does not send robot commands.
EOF
