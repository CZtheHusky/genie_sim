# Genie Sim on Aliyun DSW

This document describes a DSW-native Genie Sim / Isaac Sim image. It is for
simulation and replay-tool development first. It does not control a real G2
robot and does not send real robot motion commands.

## Why Not `scripts/start_gui.sh`

The official Docker flow assumes a normal host with Docker daemon access:

- `scripts/dockerfile` builds from `nvcr.io/nvidia/isaac-sim:5.1.0`.
- `scripts/start_gui.sh` and `scripts/start_headless.sh` run
  `registry.agibot.com/genie-sim/open_source:latest` with `docker run`.
- Both scripts bind mount the current repo into the container as
  `/geniesim/main`.
- They mount host-side Isaac Sim cache directories into:
  `/isaac-sim/.cache`, `/isaac-sim/.nv/ComputeCache`,
  `/isaac-sim/.nvidia-omniverse/logs`,
  `/isaac-sim/.nvidia-omniverse/config`,
  `/isaac-sim/.local/share/ov/data`, and `/isaac-sim/.local/share/ov/pkg`.
- `start_gui.sh` forwards the host `DISPLAY` and calls `xhost +local:`.
- `scripts/entrypoint.sh` assumes `/geniesim/main` already exists from the
  runtime mount. It sets `SIM_REPO_ROOT=/geniesim/main`, `ENABLE_SIM=1`,
  `ISAACSIM_HOME=/isaac-sim`, ROS Jazzy variables,
  `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`, and appends the Isaac Sim ROS bridge
  library path to `LD_LIBRARY_PATH`.
- `scripts/entrypoint.sh` also runs runtime installs:
  `/isaac-sim/python.sh -m pip install /geniesim/main/3rdparty/ik_solver-0.4.3-cp311-cp311-linux_x86_64.whl`
  and `/isaac-sim/python.sh -m pip install -e /geniesim/main/source`.
- `scripts/into.sh` only runs `docker exec -it genie_sim_benchmark bash`.

Aliyun DSW is already a container environment. It should pull and run a final
image, not run Docker inside itself. Therefore this DSW image copies the repo
into `/geniesim/main` at build time, performs Python installs during build, and
uses container-internal VNC/noVNC startup scripts.

## Files Added

- `Dockerfile.dsw`: DSW-native image based on Isaac Sim 5.1.0 with ROS Jazzy,
  Genie Sim dependencies, repo source, editable install, TigerVNC/noVNC/XFCE,
  and DSW entry scripts.
- `docker/dsw_entrypoint.sh`: lightweight runtime entrypoint. It exports Genie
  Sim, Isaac Sim, and ROS variables, creates writable runtime directories, and
  starts the requested command.
- `docker/start_vnc.sh`: starts XFCE on VNC display `:1` and exposes noVNC on
  port `6080`.
- `docker/start_geniesim_gui.sh`: starts `source/geniesim/app/app.py` through
  `/isaac-sim/python.sh`, defaulting to `source/geniesim/config/s2r_organize_items.yaml`
  when present.
- `docker/start_geniesim_headless.sh`: minimal GPU, Isaac Sim Python, Genie Sim
  path, and assets-path check for later replay dry-runs.
- `.dockerignore`: keeps local metadata, caches, logs, recordings, and archives
  out of the Docker build context.

`source/geniesim/.gitignore` ignores `assets/`, so `Dockerfile.dsw` creates a
tiny `source/geniesim/assets/__init__.py` placeholder inside the image only when
that package is missing. Full assets can replace or extend this directory later.

## Build Outside DSW

Build this image on ECS, OOS temporary ECS, ACR build, a self-hosted GitHub
Actions runner, or another machine that supports Docker and NVIDIA/Isaac Sim
base-image pulls. Do not build inside DSW.

Set your values:

```bash
export ACR_REGISTRY=registry.cn-beijing.aliyuncs.com
export ACR_NAMESPACE=<namespace>
export IMAGE_NAME=genie-sim-dsw
export TAG=<tag>
```

Log in to ACR:

```bash
docker login ${ACR_REGISTRY}
```

Build and push with BuildKit registry cache:

```bash
docker buildx create --use --name genie-builder || docker buildx use genie-builder

docker buildx build \
  -f Dockerfile.dsw \
  -t ${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:${TAG} \
  --cache-from=type=registry,ref=${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:buildcache \
  --cache-to=type=registry,ref=${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:buildcache,mode=max \
  --push \
  .
```

The Dockerfile uses BuildKit cache mounts for apt and pip. It intentionally does
not use `pip install --no-cache-dir`, so dependency layers and BuildKit cache can
be reused. Isaac Sim itself comes from `nvcr.io/nvidia/isaac-sim:5.1.0`; Docker
and the registry cache will avoid downloading unchanged layers repeatedly.

Final image address:

```text
registry.cn-beijing.aliyuncs.com/<namespace>/genie-sim-dsw:<tag>
```

Build cache image:

```text
registry.cn-beijing.aliyuncs.com/<namespace>/genie-sim-dsw:buildcache
```

## Create DSW Instance

In Aliyun DSW, create an instance and choose Custom Image. Fill in:

```text
registry.cn-beijing.aliyuncs.com/<namespace>/genie-sim-dsw:<tag>
```

Choose a GPU instance type that supports Isaac Sim RTX workloads. DSW only pulls
and runs this image. It should not run `docker run`, `scripts/start_gui.sh`, or
any Docker daemon inside the DSW container.

## Expose noVNC

After the DSW instance starts, open a terminal and run:

```bash
start_vnc.sh
```

The script starts:

- VNC display: `:1`
- VNC port: `5901`
- noVNC/websockify port: `6080`
- XFCE desktop

In the DSW console, expose port `6080` as a Custom Service / Web Service. Open
the generated DSW service URL in your browser. The default VNC password is
`geniesim`; override it before startup if needed:

```bash
export VNC_PASSWORD='your-password'
start_vnc.sh
```

This image currently uses TigerVNC from Ubuntu packages for reliability. To
switch to TurboVNC later, add the TurboVNC `.deb` install to `Dockerfile.dsw`
and replace the `vncserver` command in `docker/start_vnc.sh` with TurboVNC's
server command. The noVNC/websockify port model can stay the same.

## Verify Environment

Run these inside DSW:

```bash
nvidia-smi
/isaac-sim/python.sh --version
echo ${SIM_REPO_ROOT}
echo ${SIM_ASSETS}
start_geniesim_headless.sh
```

Expected defaults:

```text
SIM_REPO_ROOT=/geniesim/main
SIM_ASSETS=/geniesim/main/source/geniesim/assets
ISAACSIM_HOME=/isaac-sim
ROS_DISTRO=jazzy
RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
```

## Start Genie Sim GUI

Start VNC first:

```bash
start_vnc.sh
```

Then start Genie Sim:

```bash
start_geniesim_gui.sh
```

The default config resolution is:

1. `source/geniesim/config/organize_items.yaml`
2. `source/geniesim/config/s2r_organize_items.yaml`
3. `source/geniesim/config/config.yaml`

This repo currently contains `s2r_organize_items.yaml`, not
`organize_items.yaml`.

Use a custom config:

```bash
start_geniesim_gui.sh source/geniesim/config/s2r_place_block_into_box.yaml
```

If the config path is wrong, the script lists available configs instead of
failing silently.

## Assets Strategy

Current repo state:

- G2 robot config/URDF/mesh files exist under paths such as
  `source/geniesim/app/robot_cfg`, `source/data_collection/config/robot_cfg/G2`,
  and `source/teleop/app/share/genie_robot_description`.
- The expected code path `source/geniesim/assets` did not exist originally.
  This DSW setup creates only a tiny placeholder Python package there at image
  build time if no real assets package is present.
- `source/geniesim_world/assets` currently contains only `project.png`; it is
  not a complete GenieSimAssets bundle.

Recommended options:

1. Minimal built-in assets, preferred first step:
   include only the G2 replay/demo assets that are proven necessary. This keeps
   image size manageable and is closest to "open DSW and start working". The
   exact minimal USD/object set still needs to be identified from the replay
   demo you choose.
2. Full built-in assets:
   copy all GenieSimAssets into `source/geniesim/assets` during image build.
   This is most self-contained, but the image can become very large and may
   fail DSW pulls or exceed system disk capacity.
3. DSW-mounted assets:
   mount assets from OSS, NAS, CPFS, or a DSW dataset to
   `/geniesim/main/source/geniesim/assets` or set `SIM_ASSETS` to that mounted
   path. This keeps the image smaller but is not fully self-contained.

## Common Issues

- DSW cannot run Docker daemon:
  build on ECS/OOS/ACR/GitHub runner, then use the pushed ACR image in DSW.
- Official `scripts/start_gui.sh` fails:
  it calls `docker run`, bind mounts the repo, and expects a host `DISPLAY`.
  Use `start_vnc.sh` and `start_geniesim_gui.sh` instead.
- Image pull fails or disk fills up:
  Isaac Sim and ROS images are large. Avoid bundling full datasets until needed,
  and choose a DSW instance with enough system disk.
- noVNC page does not open:
  expose DSW Custom Service / Web Service port `6080`.
- VNC opens but Isaac Sim is black:
  check `nvidia-smi`, GPU type, NVIDIA runtime availability, and whether the
  GPU supports RTX/RT Core workloads required by Isaac Sim rendering.
- Assets are missing:
  populate `source/geniesim/assets` with the minimal demo assets or mount a
  dataset there. The current image includes only a placeholder package.
- Config file does not exist:
  run `find source/geniesim/config -maxdepth 1 -name '*.yaml' | sort` or call
  `start_geniesim_gui.sh bad/path.yaml` to print available configs.

## Replay Tool Next Step

Keep the first phase simulation-only:

- implement replay against Genie Sim only;
- do not directly control the real G2;
- define a `SimAdapter` for Isaac/Genie Sim actions and observations;
- later define a separate `RealGDKAdapter` with explicit safety gates before
  any real robot integration.
