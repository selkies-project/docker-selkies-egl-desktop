# docker-selkies-egl-desktop

KDE Plasma desktop container for [Selkies](https://github.com/selkies-project/selkies), built on the [Selkies base container](https://github.com/selkies-project/selkies/tree/main/addons/base): a complete remote desktop streamed over WebSockets or WebRTC to a browser, with hardware acceleration on NVIDIA, AMD and Intel GPUs and a software fallback without one. The GPU is reached the way the base reaches it, through EGL and DRI3 with no X.Org server of its own, so one GPU can serve as many of these containers as it has memory for and no `/tmp/.X11-unix` host socket or host configuration is involved.

Plasma runs on the base's X11 framebuffer server by default, and natively on the headless Wayland backend with `SELKIES_WAYLAND=true`, where a nested `kwin_wayland` is the session compositor. Both backends show a second display in a second browser window.

Use [docker-selkies-glx-desktop](https://github.com/selkies-project/docker-selkies-glx-desktop) for the same desktop on an X.Org server that owns the GPU, which is what an application that needs the vendor's own GLX stack, or the last bit of OpenGL performance, wants; that image gives one GPU to one container.

[![Build](https://github.com/selkies-project/docker-selkies-egl-desktop/actions/workflows/container-publish.yml/badge.svg)](https://github.com/selkies-project/docker-selkies-egl-desktop/actions/workflows/container-publish.yml)

[![Discord](https://img.shields.io/badge/dynamic/json?logo=discord&label=Discord%20Members&query=approximate_member_count&url=https%3A%2F%2Fdiscordapp.com%2Fapi%2Finvites%2FwDNGDeSW5F%3Fwith_counts%3Dtrue)](https://discord.gg/wDNGDeSW5F)

**Please read [Troubleshooting](#troubleshooting) first, then use [Discord](https://discord.gg/wDNGDeSW5F) or [GitHub Discussions](https://github.com/selkies-project/docker-selkies-egl-desktop/discussions) for support questions. Please only use [Issues](https://github.com/selkies-project/docker-selkies-egl-desktop/issues) for technical inquiries or bug reports.**

## What is in the image

The [Selkies base container](https://github.com/selkies-project/selkies/blob/main/docs/component.md#desktop-container) supplies everything but the desktop: the display servers (XLibre's Xvfb with glamor and DRI3, and the headless Wayland backend), PipeWire audio, the GPU runtime wiring for NVIDIA, VA-API and Vulkan, the gamepad and webcam plumbing, [s6](https://skarnet.org/software/s6/) service supervision, an embedded [coTURN](https://github.com/coturn/coturn) server for the WebRTC transport, and Selkies itself. This image adds KDE Plasma (`plasma-desktop` with Dolphin, Konsole, KWrite, Gwenview, Ark and System Settings), Firefox and Google Chrome, and the [proot-apps](https://github.com/linuxserver/proot-apps) runner behind the dashboard's apps panel, which installs portable applications into the home directory without touching the image.

On the Wayland backend a second display is a kwin virtual output, which the distribution's kwin never registers on its nested backend, so the image rebuilds `kwin-wayland` from the Ubuntu source package with the patch under [`patches/`](patches/). The rebuilt packages are the archive's exact version, which is why the image is Ubuntu 26.04 only.

OpenGL on NVIDIA GPUs runs on the driver's own GLX client library over the display server's DRI3, with [Zink](https://docs.mesa3d.org/drivers/zink.html) on the NVIDIA Vulkan driver for EGL and for a container without a render node, in place of the VirtualGL the previous generation of this image translated GLX through: no interposer, no second X server, and the same path on both backends.

Container tags are `26.04` for the current Ubuntu 26.04 build, `latest` for the same, and persistent tags of the form `26.04-20260101010101` for a specific build.

## Usage

### Running with Docker

**1. Run the container with Docker or Podman.**

With an NVIDIA GPU (the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) is required):

```bash
docker run --name egl -it -d --gpus 1 --runtime nvidia --shm-size=2g -e TZ=UTC -e PASSWD=mypasswd -p 8080:8080 ghcr.io/selkies-project/selkies-egl-desktop:26.04
```

With an AMD or Intel GPU, pass the DRM devices in instead. The session user inside the container (uid 1000) must be able to open them, which `--group-add` covers when the host's `render` and `video` groups own the nodes:

```bash
docker run --name egl -it -d --device=/dev/dri:rwm --group-add="$(getent group render | cut -d: -f3)" --group-add="$(getent group video | cut -d: -f3)" --shm-size=2g -e TZ=UTC -e PASSWD=mypasswd -p 8080:8080 ghcr.io/selkies-project/selkies-egl-desktop:26.04
```

Without a GPU the same command minus the device options runs the desktop in software, with the x264 video encoder.

**Alternatively, use Docker Compose by editing [`docker-compose.yml`](docker-compose.yml):**

```bash
# Start the container from the path containing docker-compose.yml
docker compose up -d
# Stop the container
docker compose down
```

`--shm-size=2g` matters because the browsers inside the desktop crash on Docker's 64 MB default. Replace `mypasswd` with your own password. The container must NOT be run in privileged mode.

**2. Connect to the web server on port 8080 with a browser.** You may also put a reverse proxy in front of it for external connectivity.

The container serves HTTPS by default on a certificate it mints per install, so the browser warns once until you trust it or name a real certificate with `-e SELKIES_HTTPS_CERT=` and `-e SELKIES_HTTPS_KEY=`; `-e SELKIES_ENABLE_HTTPS=false` serves plain HTTP for a deployment that terminates TLS in front of the container.

The login is `ubuntu` with the password from `PASSWD` (which is also the container's Linux user password) unless `SELKIES_BASIC_AUTH_USER` and `SELKIES_BASIC_AUTH_PASSWORD` name another one.

**3. If the desktop loads but does not stream, or streams very slowly, read [WebRTC and Firewall Issues](#webrtc-and-firewall-issues).** The default WebSocket transport needs nothing but the web port. The WebRTC transport (`-e SELKIES_MODE=webrtc`) needs a TURN server or host networking, because you are self-hosting WebRTC.

### Running with Kubernetes

**1. Create the Kubernetes `Secret` with your password (change keys and values as adequate):**

```bash
kubectl create secret generic my-pass --from-literal=my-pass=YOUR_PASSWORD
```

> NOTE: Replace `YOUR_PASSWORD` with your desired password, and change the name `my-pass` to your preferred name of the Kubernetes secret with the `egl.yml` file changed accordingly as well. It is possible to skip this step and provide the password with `value:` in `egl.yml`, but this exposes the password in plain text.

**2. Create the pod after editing [`egl.yml`](egl.yml) to your needs; explanations are in the file:**

```bash
kubectl create -f egl.yml
```

The file requests an NVIDIA GPU through the NVIDIA device plugin. AMD and Intel GPUs are requested through their own device plugins (`amd.com/gpu`, `gpu.intel.com/i915`) in the same `resources:` section.

**3. Connect to the web server on port 8080** through the ingress or reverse proxy your cluster provides. The login is the same as with Docker.

**4. If the desktop loads but does not stream, read [WebRTC and Firewall Issues](#webrtc-and-firewall-issues).**

### Running with Apptainer

On a cluster without Docker, the image runs under Apptainer as an ordinary user, pulled straight from the registry: a job on a GPU node keeps the desktop for its lifetime, with a display number and a port that no other session on the node uses (a job id from the scheduler is a good seed for both), a private `/tmp` for the session's sockets, and a directory of your own as the desktop's home.

```bash
#!/bin/bash
N=$((RANDOM % 900 + 100))
PORT=$((RANDOM % 10000 + 20000))
mkdir -p "$HOME/selkies/home" "$HOME/selkies/tmp"
apptainer run --nv --writable-tmpfs --contain --cleanenv \
    --home "$HOME/selkies/home:/home/ubuntu" -B "$HOME/selkies/tmp:/tmp" -B /dev/dri \
    --env "DISPLAY=:$N,SELKIES_PORT=$PORT,PASSWD=mypasswd" \
    docker://ghcr.io/selkies-project/selkies-egl-desktop:26.04
```

Reach it with `ssh -L 8080:<node>:$PORT <login-node>` and open `https://localhost:8080`. The flags are explained in the [Selkies documentation](https://selkies-project.github.io/selkies/start/#apptainer), including the driver's GBM backend the Wayland backend needs bound from the host under `--nv`.

## Configuration

Everything Selkies reads is an environment variable named in [`docs/settings.md`](https://github.com/selkies-project/selkies/blob/main/docs/settings.md) (`selkies --help` inside the container lists the same). The ones this image adds or that matter most:

| Variable | Default | Meaning |
| --- | --- | --- |
| `PASSWD` | `mypasswd` | Password of the container's Linux user, and of the web login unless `SELKIES_BASIC_AUTH_PASSWORD` is set |
| `TZ` | `UTC` | Time zone |
| `SELKIES_WAYLAND` | `false` | Run the desktop on the headless Wayland backend (nested kwin) instead of the X11 framebuffer server |
| `SELKIES_MODE` | `websockets` | Transport: `websockets` or `webrtc`; both can be switched from the web interface |
| `SELKIES_ENCODER` | `h264enc` | Video encoder: `h264enc` (hardware NVENC or VA-API when the GPU has it, x264 otherwise), `h264enc-striped`, or `jpeg` |
| `SELKIES_VIDEO_BITRATE`, `SELKIES_FRAMERATE`, `SELKIES_AUDIO_BITRATE` | `8000`, `60`, `128000` | Initial stream parameters, adjustable from the web interface |
| `SELKIES_ENABLE_HTTPS` | `true` | Serve TLS; `SELKIES_HTTPS_CERT` and `SELKIES_HTTPS_KEY` name a real certificate |
| `SELKIES_ENABLE_BASIC_AUTH` | `true` | The web login, `ubuntu` and `PASSWD` unless `SELKIES_BASIC_AUTH_USER` and `SELKIES_BASIC_AUTH_PASSWORD` are set |
| `SELKIES_SCALING_DPI` | `96` | The desktop's DPI, also adjustable from the web interface |
| `SELKIES_AUTO_GPU` | `true` | Which GPU the session renders on when the container was given several |
| `SELKIES_COMMAND_ENABLED` | `true` | The command channel behind the dashboard's apps panel; `false` disables it |
| `START_PLASMA` | `true` | `false` runs the display server with kwin alone, no Plasma shell: a single application started from the apps panel or an attached shell is managed, resized and maximized without a desktop around it |

The base container's own variables apply as well: `SELKIES_WAYLAND_COMPOSITOR` names the nested compositor (this image sets it to the Plasma session), `DISABLE_ZINK=true` leaves an NVIDIA GPU to software OpenGL instead of routing it through Zink, and the `SELKIES_TURN_*` variables configure the WebRTC transport.

### Backends

On the default X11 backend the desktop draws on the base's Xvfb, XLibre's, whose glamor renders the server's own drawing on the GPU and whose DRI3 lets applications present their frames into it without a copy; on NVIDIA GPUs GLX applications render on the driver's own client library and present through that DRI3, EGL ones through Zink on the NVIDIA Vulkan driver, and the server paces presents at the screen's refresh. The stream is read back from that server's screen once per frame, where the Wayland backend hands the encoder the compositor's buffer as it is, which keeps the Wayland backend the lighter of the two. Plasma's own compositing is off in the system defaults (System Settings can turn it on), since every desktop animation is bandwidth for nothing on a stream.

With `SELKIES_WAYLAND=true` the whole session runs on Wayland: Selkies' own capture compositor owns the screens, and Plasma's `kwin_wayland` nests inside it, managing windows and running the XWayland server X11-only applications draw on. The compositor renders through GBM on the GPU's DRM render node. The NVIDIA Container Toolkit creates and exposes those nodes with `--gpus`; a toolkit that does not needs `--device=/dev/dri` and the host's `render` group (`--group-add`) passed, as for AMD and Intel GPUs. Where the compositor cannot reach the GPU at all, the base falls back to the X11 backend so the session keeps it (`SELKIES_WAYLAND_X11_FALLBACK=false` keeps Wayland and composites in software).

On X11 the Plasma shell lays its panels and wallpaper out for the DPI it started at and follows a later change only in part, so the image replaces the shell when the dashboard's UI scaling changes: the desktop lays out afresh at the new size within a few seconds, and open windows stay where they are. A second display is opened from the dashboard on either backend, in a second browser window. On Wayland each display is a screen of the capture compositor and kwin grows a matching virtual output for it, removed again when the display disconnects, with its windows returning to the primary; panels, maximized windows and the desktop are laid out per screen. On X11 each display is a RandR monitor on the framebuffer server's one output, and the image's `kwin_x11` is rebuilt to take its screens from those monitors (`patches/kwin-x11/`): a stock kwin_x11 reads them from RandR CRTCs, of which that server has one, and would span both displays with a maximized window. So panels, maximized windows and the desktop are laid out per display on either backend.

### Apps panel

The dashboard's apps panel installs applications from the [proot-apps](https://github.com/linuxserver/proot-apps) catalogue into the home directory. They persist with the home directory (mount a volume at `/home/ubuntu` to keep them) and never touch the image. `sudo apt-get install` works inside the session as well, through fakeroot, for packages the image should carry; `sudo-root` is the real thing, for device nodes and permissions only.

## WebRTC and Firewall Issues

This section applies only to the WebRTC transport (`SELKIES_MODE=webrtc`, or switching to it in the web interface); the default WebSocket transport needs only the web port.

Self-hosted WebRTC needs a [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server) when the client and the container cannot reach each other directly, which is the case behind most NATs and firewalls, and always inside Docker's network isolation. Choose one of the following.

- **Internal TURN server:** the container runs its own coTURN when it has no external one. Publish its ports with `-p 3478:3478 -p 3478:3478/udp -p 65532-65535:65532-65535 -p 65532-65535:65532-65535/udp` (or uncomment them in `docker-compose.yml` / `egl.yml`) and set `-e TURN_MIN_PORT=65532 -e TURN_MAX_PORT=65535` to that range, which must contain at least two ports no other process uses. Set `-e SELKIES_TURN_HOST=` to the address clients reach the container on when it is not the public one, and `-e SELKIES_TURN_PROTOCOL=tcp` when UDP cannot be used, at the cost of latency.

- **Host networking:** `--network=host` (or `network_mode: 'host'` / `hostNetwork: true`) with UDP and TCP ports 49152–65535 open in the host's firewall usually just works. Display `:20` must then be free on the host, and a second container needs its own `-e DISPLAY=:22 -e SELKIES_PORT=8082`; the cluster may not allow it.

- **External TURN server:** set `SELKIES_TURN_HOST` and `SELKIES_TURN_PORT`, then either `SELKIES_TURN_SHARED_SECRET` (time-limited shared secret authentication) or both `SELKIES_TURN_USERNAME` and `SELKIES_TURN_PASSWORD` (long-term credentials), never both methods at once. `SELKIES_TURN_PROTOCOL=tcp` when UDP is blocked; `SELKIES_TURN_TLS=true` when the TURN server has a valid certificate. A [TURN REST API](https://github.com/selkies-project/selkies/blob/main/docs/component.md#turn-rest) is named with `SELKIES_TURN_REST_URI` alone. The Selkies [firewall documentation](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md) covers deploying one; with Kubernetes, keep the credentials in a `Secret` the way `egl.yml` shows.

## Troubleshooting

### The container does not work with an NVIDIA GPU.

<details markdown>
  <summary>Open Answer</summary>

Check that the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) is configured on the host and the container was started with `--gpus`, that the host driver is not the `nvidia-headless` variant (it lacks the graphics libraries), and that `NVIDIA_DRIVER_CAPABILITIES` inside the container is `all` or includes `graphics` (OpenGL, Vulkan), `video` (NVENC) and `compute`. Vulkan needs `display` as well. `nvidia-smi` and `vulkaninfo --summary` inside the container show what the driver exposes; the container's log names the GPU the session renders on and why it fell back if it did.

</details>

### The container does not work with an AMD or Intel GPU.

<details markdown>
  <summary>Open Answer</summary>

The container needs `/dev/dri` (`--device=/dev/dri:rwm`) and the session user must be able to open the nodes: add the host's `render` and `video` groups with `--group-add`, or as a last resort `sudo chmod -R 777 /dev/dri` on the host. `vainfo` and `vulkaninfo --summary` inside the container show the driver; the container's log names the render node the session picked, and `SELKIES_AUTO_GPU` or `SELKIES_RENDER_DRI` selects another.

</details>

### The browser inside the desktop, or another application, crashes at once.

<details markdown>
  <summary>Open Answer</summary>

Give the container more shared memory: `--shm-size=2g`, or the `/dev/shm` memory-backed `emptyDir` `egl.yml` mounts. Applications that bring their own sandbox (Chrome, Electron, AppImages) cannot set it up inside a container, which grants neither the capabilities Chrome's setuid helper needs nor unprivileged user namespaces: the container is the isolation boundary instead. Chrome's launcher in this image therefore carries `--no-sandbox`, Electron applications need the same switch, and AppImages are extracted rather than FUSE-mounted (`APPIMAGE_EXTRACT_AND_RUN` is set). Do not use `systemd`, Flatpak or Snap inside the container; they need privileges a container should not have.

</details>

### OpenGL or Vulkan does not work for an application.

<details markdown>
  <summary>Open Answer</summary>

`glxinfo -B` and `vulkaninfo --summary` inside the session show which driver answers. On NVIDIA GPUs GLX answers with the driver's own library over the display server's DRI3, and EGL with Zink on the Vulkan driver, unless the runtime injects the driver's xcb EGL platform library, which puts EGL on the NVIDIA driver too; an application that needs that module belongs on [docker-selkies-glx-desktop](https://github.com/selkies-project/docker-selkies-glx-desktop). `DISABLE_ZINK=true` keeps Zink out of the session: EGL then falls to software OpenGL, and GLX keeps the driver's library where the server has DRI3. Zink, and every Vulkan application, presents only where the container has the driver's modeset node, `/dev/nvidia-modeset`; a runtime that withholds it leaves EGL to software rendering, which the container log reports. A host whose `nvidia-drm` module runs with modesetting off gives the driver no working GBM: the log then calls the GPU unusable, the Wayland backend falls back to X11, the framebuffer server stays in software, and OpenGL runs through Zink.

</details>

### I want to use a specific GPU when the container has several.

<details markdown>
  <summary>Open Answer</summary>

`--gpus '"device=1,2"'` gives the container the NVIDIA GPUs with device IDs 1 and 2 (`--gpus 1` means any single GPU). Among the GPUs the container was given, `SELKIES_AUTO_GPU` picks the one the session renders on and `SELKIES_ENCODE_DRI` the one the video encoder uses; the container's log names the choice.

</details>

### I want to customize this container.

Build on it the way [`docs/development.md`](https://github.com/selkies-project/selkies/blob/main/docs/development.md#container-customization) describes: use this image as the base and replace or add s6 service files under `/etc/service/`. Every service here is one `run` script: `plasma` (the X11 session), `dbus-session` (the session bus), and the base's own. The Wayland session runs under the base's `wayland` service, through `selkies-kwin`.

## Building

```bash
docker build -t selkies-egl-desktop --build-arg BASE_IMAGE=ghcr.io/selkies-project/selkies/base:main-ubuntu26.04 .
```

`BASE_IMAGE` is any Ubuntu 26.04 Selkies base container, by tag or digest. The build rebuilds `kwin-wayland` from the archive source with the patch under `patches/`, which takes a while; `SELKIES_REF` names the Selkies revision the shared helper scripts are taken from (`main`).

---
This project has been developed and is supported in part by the National Research Platform (NRP) and the Cognitive Hardware and Software Ecosystem Community Infrastructure (CHASE-CI) at the University of California, San Diego, by funding from the National Science Foundation (NSF), with awards #1730158, #1540112, #1541349, #1826967, #2138811, #2112167, #2100237, and #2120019, as well as additional funding from community partners, infrastructure utilization from the Open Science Grid Consortium, supported by the National Science Foundation (NSF) awards #1836650 and #2030508, and infrastructure utilization from the Chameleon testbed, supported by the National Science Foundation (NSF) awards #1419152, #1743354, and #2027170. This project has also been funded by the Seok-San Yonsei Medical Scientist Training Program (MSTP) Song Yong-Sang Scholarship, College of Medicine, Yonsei University, the MD-PhD/Medical Scientist Training Program (MSTP) through the Korea Health Industry Development Institute (KHIDI), funded by the Ministry of Health & Welfare, Republic of Korea, and the Student Research Bursary of Song-dang Institute for Cancer Research, College of Medicine, Yonsei University.

<sub><sup>\* Funding agencies including, but not limited to the National Science Foundation, remain neutral with regard to jurisdictional claims in published articles and software code of this Code Repository. In the context including, but not limited to this Code Repository, as well as in the context including, but not limited to any and all derivative works based on this Code Repository, all trademarks, trade names, logos, patents, or any and all other forms of external intellectual property, that are mentioned or used, unless otherwise stated, are the property of their respective owners, including but not limited to, The Linux Foundation®, Linus Torvalds, The Apache Software Foundation, Canonical Ltd., Google LLC, Alphabet Inc., NumFOCUS Foundation, Anaconda Inc., conda-forge, Project Jupyter, Coder Technologies, Inc., Docker®, Inc., SchedMD LLC, NVIDIA Corporation, Intel Corporation, Advanced Micro Devices, Inc., Valve Corporation, Epic Games, Inc., Unity Software Inc., Cendio AB, RealVNC® Limited, Amazon.com, Inc., Amazon Web Services, Inc., or its affiliates including but not limited to NICE s.r.l. or NICE USA LLC, Microsoft Corporation, Cloudflare, Inc., Oracle Corporation, StarNet Communications Corporation, TeamViewer SE, Fabrice Bellard, Moonlight Project, and LizardByte. Every best effort has been undertaken to properly identify and attribute trademarks, trade names, logos, patents, or any and all other forms of external intellectual property to their respective owners, unless otherwise stated, wherever possible and practical. The inclusion of such trademarks, trade names, logos, patents, or any and all other forms of external intellectual property in association with this project, unless otherwise stated, serves solely for the purpose of description and must never be construed as an indication of affiliation, competition, endorsement, or a challenge to any and all legal standings of the trademarks, trade names, logos, patents, or any and all other forms of external intellectual property. All project contributors, maintainers, owners, or organizations agree to not willfully breach or infringe legal regulations, in any and all global law, regarding trademarks, trade names, logos, patents, or any and all other forms of external intellectual property. Therefore, all project contributors, maintainers, owners, or organizations, are immune to, and are not to be in any and all cases held legally liable for, any and all jurisdictional claims on trademarks, trade names, logos, patents, or any and all other forms of external intellectual property. No component of this Code Repository is an official product of Google LLC or Alphabet Inc.</sup></sub>
