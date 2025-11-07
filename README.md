# docker-selkies-egl-desktop

KDE Plasma Desktop container designed for Kubernetes, supporting OpenGL EGL and GLX, Vulkan, and Wine/Proton for NVIDIA GPUs through WebRTC and HTML5, providing an open-source remote cloud/HPC graphics or game streaming platform. Directly accesses the GPU without an X.Org X11 Server using EGL with [VirtualGL](https://github.com/VirtualGL/virtualgl) and Vulkan, not requiring `/tmp/.X11-unix` host sockets or host configuration.

Use [docker-selkies-glx-desktop](https://github.com/selkies-project/docker-selkies-glx-desktop) for a KDE Plasma Desktop container with better performance, having fully optimized OpenGL and Vulkan for NVIDIA GPUs by spawning its own fully isolated X.Org X11 Server, also not using `/tmp/.X11-unix` host sockets.

[![Build](https://github.com/selkies-project/docker-selkies-egl-desktop/actions/workflows/container-publish.yml/badge.svg)](https://github.com/selkies-project/docker-selkies-egl-desktop/actions/workflows/container-publish.yml)

[![Discord](https://img.shields.io/badge/dynamic/json?logo=discord&label=Discord%20Members&query=approximate_member_count&url=https%3A%2F%2Fdiscordapp.com%2Fapi%2Finvites%2FwDNGDeSW5F%3Fwith_counts%3Dtrue)](https://discord.gg/wDNGDeSW5F)

**Please read [Troubleshooting](#troubleshooting) first, then use [Discord](https://discord.gg/wDNGDeSW5F) or [GitHub Discussions](https://github.com/selkies-project/docker-selkies-egl-desktop/discussions) for support questions. Please only use [Issues](https://github.com/selkies-project/docker-selkies-egl-desktop/issues) for technical inquiries or bug reports.**

## Usage

This container is composed fully of vendor-neutral applications and protocols except the NVIDIA userspace driver components, indicating that **there is nothing stopping you from using this container with GPUs of other vendors including AMD and Intel**. Use the container toolkit/runtime or Kubernetes device plugin of each respective vendor, or make sure that it provisions `/dev/dri/card[n]` and `/dev/dri/renderD[128 + n]` devices using `--device=/dev/dri:rwm` **with sufficient host user permissions for the devices (`sudo chmod -R -f 777 /dev/dri` from the host)**, then set the [environment variable `SELKIES_ENCODER`](https://github.com/selkies-project/selkies/blob/main/docs/component.md#encoders) to values including `vah264enc`, `x264enc`, `vp8enc`, or `vp9enc` if using the Selkies WebRTC interface. However, this is not officially supported and issues may arise. This container also supports running without any GPUs with software fallback (set the [environment variable `SELKIES_ENCODER`](https://github.com/selkies-project/selkies/blob/main/docs/component.md#encoders) to values including `x264enc`, `vp8enc`, or `vp9enc` if using the Selkies WebRTC interface).

Container startup may take some time at first launch as it could automatically install NVIDIA driver libraries compatible with the host.

For Windows applications or games, Wine, Winetricks, Lutris, Heroic Launcher, PlayOnLinux, and q4wine are bundled by default. Comment out the section where it is installed within `Dockerfile` if the user wants containers without Wine.

The container requires host NVIDIA GPU driver versions of at least **450.80.02** and preferably **470.42.01** (the latest minor version in each major version), with the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) to be also configured on the host for allocating GPUs. The latest minor versions (`xx` in `000.xx.00`) are strongly encouraged. All Maxwell or later generation GPUs in the consumer, professional, or datacenter lineups should not have significant issues running this container, although the Selkies high-performance NVENC backend may not be available. Kepler GPUs are untested and likely does not support the NVENC backend, but can be mostly functional using fallback software acceleration.

The high-performance NVENC backend for the Selkies WebRTC interface is only supported in GPUs listed as supporting `H.264 (AVCHD)` under the `NVENC - Encoding` section of NVIDIA's [Video Encode and Decode GPU Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new). If your GPU is not listed as supporting `H.264 (AVCHD)`, add the [environment variable `SELKIES_ENCODER`](https://github.com/selkies-project/selkies/blob/main/docs/component.md#encoders) to values including `x264enc`, `vp8enc`, or `vp9enc` in your container configuration for falling back to software acceleration, which also has a very good performance depending on your CPU.

There are two web interfaces that may be chosen in this container, the first being the default [Selkies](https://github.com/selkies-project/selkies) WebRTC HTML5 web interface (requires a TURN server or host networking for best performance), and the second being the fallback [KasmVNC](https://github.com/kasmtech/KasmVNC) WebSocket HTML5 web interface. While the KasmVNC interface does not support audio forwarding, it can be useful for troubleshooting the Selkies WebRTC interface or using this container in constrained environments.

The KasmVNC interface can be enabled in place of Selkies by setting `KASMVNC_ENABLE` to `true`. `KASMVNC_THREADS` sets the number of threads KasmVNC should use for frame encoding, defaulting to all threads if not set. When using the KasmVNC interface, environment variables `SELKIES_ENABLE_BASIC_AUTH`, `SELKIES_BASIC_AUTH_USER`, `SELKIES_BASIC_AUTH_PASSWORD`, `SELKIES_ENABLE_RESIZE`, `SELKIES_ENABLE_HTTPS`, `SELKIES_HTTPS_CERT`, `SELKIES_HTTPS_KEY`, `SELKIES_PORT`, `NGINX_PORT`, and `TURN_EXTERNAL_IP`, used with Selkies, are also inherited. As with the Selkies WebRTC interface, the KasmVNC interface username and password will also be set to the environment variables `SELKIES_BASIC_AUTH_USER` and `SELKIES_BASIC_AUTH_PASSWORD`, also using `ubuntu` and the environment variable `PASSWD` by default if not set.

### Running with Docker

**1. Run the container with Docker, Podman, or other NVIDIA-supported container runtimes ([NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) required):**

```bash
docker run --name egl -it -d --gpus 1 --runtime nvidia --tmpfs /dev/shm:rw -e TZ=UTC -e DISPLAY_SIZEW=1920 -e DISPLAY_SIZEH=1080 -e DISPLAY_REFRESH=60 -e DISPLAY_DPI=96 -e DISPLAY_CDEPTH=24 -e PASSWD=mypasswd -e SELKIES_ENCODER=nvh264enc -e SELKIES_VIDEO_BITRATE=8000 -e SELKIES_FRAMERATE=60 -e SELKIES_AUDIO_BITRATE=128000 -e SELKIES_BASIC_AUTH_PASSWORD=mypasswd -p 8080:8080 ghcr.io/selkies-project/nvidia-egl-desktop:latest
```

**Alternatively, use Docker Compose by editing the [`docker-compose.yml`](docker-compose.yml) file:**

```bash
# Start the container from the path containing docker-compose.yml
docker compose up -d
# Stop the container
docker compose down
```

**If the Selkies WebRTC HTML5 interface does not connect or is extremely slow, read Step 3 and the [WebRTC and Firewall Issues](#webrtc-and-firewall-issues) section very carefully.**

> NOTE: The container tags available are `latest` and `24.04` for Ubuntu 24.04, `22.04` for Ubuntu 22.04, and `20.04` for Ubuntu 20.04. [Persistent container tags](https://github.com/selkies-project/docker-selkies-egl-desktop/pkgs/container/nvidia-egl-desktop) are available in the form `24.04-20210101010101`. Replace all instances of `mypasswd` with your desired password. `SELKIES_BASIC_AUTH_PASSWORD` will default to `PASSWD` if unspecified. The container must NOT be run in privileged mode.

**For [Apptainer](https://github.com/apptainer/apptainer)/[Singularity](https://github.com/sylabs/singularity) (requiring NVIDIA drivers):**

```bash
# Customize paths
export SINGULARITY_SELKIES_OVERLAY=~/my_mounting_point/nvidia-egl-desktop.sif
export SINGULARITY_SELKIES_SCRATCH_HOME=~/nvidia-egl-desktop
mkdir -pm755 "${SINGULARITY_SELKIES_SCRATCH_HOME}"
# Change size of overlay storage
singularity overlay create --sparse --size 1536 "${SINGULARITY_SELKIES_OVERLAY}"
singularity instance run --overlay "${SINGULARITY_SELKIES_OVERLAY}" --nv --no-mount cwd --home "${SINGULARITY_SELKIES_SCRATCH_HOME}:/home/ubuntu" --env "TZ=UTC,DISPLAY_SIZEW=1920,DISPLAY_SIZEH=1080,DISPLAY_REFRESH=60,DISPLAY_DPI=96,DISPLAY_CDEPTH=24,PASSWD=mypasswd,SELKIES_ENCODER=nvh264enc,SELKIES_VIDEO_BITRATE=8000,SELKIES_FRAMERATE=60,SELKIES_AUDIO_BITRATE=128000,SELKIES_BASIC_AUTH_PASSWORD=mypasswd" docker://ghcr.io/selkies-project/nvidia-egl-desktop:latest egl
```

Change `SELKIES_ENCODER` to `x264enc`, `vp8enc`, or `vp9enc` when using the Selkies interface if you are using software fallback without allocated GPUs or your GPU does not support `H.264 (AVCHD)` under the `NVENC - Encoding` section in NVIDIA's [Video Encode and Decode GPU Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new).

The environment variable `VGL_DISPLAY` can also be passed to the container, but only do so after you understand what it implicates with VirtualGL, valid values being either `egl[n]`, or `/dev/dri/card[n]` only when `--device=/dev/dri:rwm` was used for the container.

**2. Connect to the web server with a browser on port 8080. You may also separately configure a reverse proxy to this port for external connectivity.**

The default username is `ubuntu` for both the web authentication prompt and the container Linux username. The environment variable `PASSWD` (defaulting to `mypasswd`) is the password for the container Linux user account, and `SELKIES_BASIC_AUTH_PASSWORD` is the password for the HTML5 interface authentication prompt. If `SELKIES_ENABLE_BASIC_AUTH` is set to `true` for Selkies but `SELKIES_BASIC_AUTH_PASSWORD` is unspecified, the HTML5 interface password will default to `PASSWD`.

> NOTE: Only one web browser can be connected at a time with the Selkies WebRTC interface. If the signaling connection works, but the WebRTC connection fails, read Step 3 and the [WebRTC and Firewall Issues](#webrtc-and-firewall-issues) section.

Additional configurations and environment variables for the Selkies WebRTC HTML5 interface are listed in lines that start with `parser.add_argument` within the [Selkies Main Script](https://github.com/selkies-project/selkies/blob/master/src/selkies_gstreamer/__main__.py) or `selkies-gstreamer --help`.

**3. (Not Applicable for KasmVNC) Read carefully if the Selkies WebRTC HTML5 interface does not connect or is extremely slow.**

A [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server) is required because you are self-hosting WebRTC, unlike commercial services using WebRTC.

Choose whether to use host networking, an internal [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server), or an external [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server).

- **Internal TURN Server:**

<details markdown>
  <summary>Open Section</summary>

There is an internal [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server) inside the container that may be used when an external [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server) or host networking is not available.

Add environment variables `-e SELKIES_TURN_PROTOCOL=udp -e SELKIES_TURN_PORT=3478 -e TURN_MIN_PORT=65532 -e TURN_MAX_PORT=65535` (change the ports accordingly) with the `docker run` command (or uncomment the relevant [`docker-compose.yml`](docker-compose.yml) sections), where the `SELKIES_TURN_PORT` should not be used by any other host process or container, and the `TURN_MIN_PORT`/`TURN_MAX_PORT` port range has to contain at least two ports also not used by any other host process or container.

Then, open the ports with the `docker run` arguments `-p 8080:8080 -p 3478:3478 -p 3478:3478/udp -p 65532-65535:65532-65535 -p 65532-65535:65532-65535/udp` (or uncomment the relevant [`docker-compose.yml`](docker-compose.yml) sections) in addition to the web server port.

If UDP cannot be used, at the cost of higher latency and lower performance, omit the ports containing `/udp` and use the environment variable `-e SELKIES_TURN_PROTOCOL=tcp`.

All these ports must be exposed to the internet if you need access over the internet. If you need use TURN within a local network, add `-e SELKIES_TURN_HOST={YOUR_INTERNAL_IP}` with `{YOUR_INTERNAL_IP}` to the internal hostname or IP of the local network. IPv6 addresses must be enclosed with square brackets such as `[::1]`.

</details>

- **Host Networking:**

<details markdown>
  <summary>Open Section</summary>

The Selkies WebRTC HTML5 interface will likely just start working if you open UDP and TCP ports 49152–65535 in your host server network and add `--network=host` to the above `docker run` command, or `network_mode: 'host'` in `docker-compose.yml`. Note that running multiple desktop containers in one host under this configuration may be problematic and is not recommended. When deploying multiple containers, you must also pass new environment variables such as `-e DISPLAY=:22`, `-e NGINX_PORT=8082`, `-e SELKIES_PORT=8083`, and `-e SELKIES_METRICS_HTTP_PORT=9083` into the container, all not overlapping with any other X11 server or container in the same host. Access the container using the specified `NGINX_PORT`.

However, host networking may be restricted or not be desired because of security reasons or when deploying multiple desktop containers in one host. If not available, check if the container starts working after omitting `--network=host`.

</details>

- **External TURN Server:**

<details markdown>
  <summary>Open Section</summary>

If having no TURN server does not work, you need an external [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server). Read the [WebRTC and Firewall Issues](#webrtc-and-firewall-issues) section and add the environment variables `-e SELKIES_TURN_HOST=`, `-e SELKIES_TURN_PORT=`, and pick one of `-e SELKIES_TURN_SHARED_SECRET=` or both `-e SELKIES_TURN_USERNAME=` and `-e SELKIES_TURN_PASSWORD=` environment variables to the `docker run` command based on your authentication method.

</details>

### Running with Kubernetes

**1. Create the Kubernetes `Secret` with your authentication password (change keys and values as adequate):**

```bash
kubectl create secret generic my-pass --from-literal=my-pass=YOUR_PASSWORD
```

> NOTE: Replace `YOUR_PASSWORD` with your desired password, and change the name `my-pass` to your preferred name of the Kubernetes secret with the `egl.yml` file changed accordingly as well. It is possible to skip the first step and directly provide the password with `value:` in `egl.yml`, but this exposes the password in plain text.

**2. Create the pod after editing the `egl.yml` file to your needs, explanations are available in the file:**

```bash
kubectl create -f egl.yml
```

**If the Selkies WebRTC HTML5 interface does not connect or is extremely slow, read Step 4 and the [WebRTC and Firewall Issues](#webrtc-and-firewall-issues) section very carefully.**

> NOTE: The container tags available are `latest` and `24.04` for Ubuntu 24.04, `22.04` for Ubuntu 22.04, and `20.04` for Ubuntu 20.04. [Persistent container tags](https://github.com/selkies-project/docker-selkies-egl-desktop/pkgs/container/nvidia-egl-desktop) are available in the form `24.04-20210101010101`. `SELKIES_BASIC_AUTH_PASSWORD` will default to `PASSWD` if unspecified. The container must NOT be run in privileged mode.

Change `SELKIES_ENCODER` to `x264enc`, `vp8enc`, or `vp9enc` when using the Selkies interface if you are using software fallback without allocated GPUs or your GPU does not support `H.264 (AVCHD)` under the `NVENC - Encoding` section in NVIDIA's [Video Encode and Decode GPU Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new).

**3. Connect to the web server spawned at port 8080. You may configure the ingress endpoint or reverse proxy that your Kubernetes cluster provides to this port for external connectivity.**

The default username is `ubuntu` for both the web authentication prompt and the container Linux username. The environment variable `PASSWD` (defaulting to `mypasswd`) is the password for the container Linux user account, and `SELKIES_BASIC_AUTH_PASSWORD` is the password for the HTML5 interface authentication prompt. If `SELKIES_ENABLE_BASIC_AUTH` is set to `true` for Selkies but `SELKIES_BASIC_AUTH_PASSWORD` is unspecified, the HTML5 interface password will default to `PASSWD`.

> NOTE: Only one web browser can be connected at a time with the Selkies WebRTC interface. If the signaling connection works, but the WebRTC connection fails, read Step 4 and the [WebRTC and Firewall Issues](#webrtc-and-firewall-issues) section.

Additional configurations and environment variables for the Selkies WebRTC HTML5 interface are listed in lines that start with `parser.add_argument` within the [Selkies Main Script](https://github.com/selkies-project/selkies/blob/master/src/selkies_gstreamer/__main__.py) or `selkies-gstreamer --help`.

**4. (Not Applicable for KasmVNC) Read carefully if the Selkies WebRTC HTML5 interface does not connect or is extremely slow.**

A [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server) is required because you are self-hosting WebRTC, unlike commercial services using WebRTC.

Choose whether to use host networking, an internal [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server), or an external [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server).

- **Internal TURN Server:**

<details markdown>
  <summary>Open Section</summary>

There is an internal [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server) inside the container that may be used when an external [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server) or host networking is not available.

Uncomment the relevant environment variables `SELKIES_TURN_PROTOCOL=udp`, `SELKIES_TURN_PORT=3478`, `TURN_MIN_PORT=65532`, `TURN_MAX_PORT=65535` (change the ports accordingly) within `egl.yml` (within `name:` and `value:`), where the `SELKIES_TURN_PORT` should not be used by any other host process or container, and the `TURN_MIN_PORT`/`TURN_MAX_PORT` port range has to contain at least two ports also not used by any other host process or container. Then, open all of these ports in the Kubernetes configuration `ports:` section in addition to the web server port.

If UDP cannot be used, at the cost of higher latency and lower performance, omit the UDP ports in the configuration and use the environment variable `SELKIES_TURN_PROTOCOL=tcp` (within `name:` and `value:`).

All these ports must be exposed to the internet if you need access over the internet. If you need use TURN within a local network, add the environment variable `SELKIES_TURN_HOST={YOUR_INTERNAL_IP}` (within `name:` and `value:`) with `{YOUR_INTERNAL_IP}` to the internal hostname or IP of the local network. IPv6 addresses must be enclosed with square brackets such as `[::1]`.

</details>

- **Host Networking:**

<details markdown>
  <summary>Open Section</summary>

Otherwise, the Selkies WebRTC HTML5 interface will likely just start working if you open UDP and TCP ports 49152–65535 in your host server network and uncomment `hostNetwork: true` in `egl.yml`. Note that running multiple desktop containers in one host under this configuration may be problematic and is not recommended. When deploying multiple containers with `hostNetwork: true`, you must also pass new environment variables such as `DISPLAY=:22`, `NGINX_PORT=8082`, `SELKIES_PORT=8083`, and `SELKIES_METRICS_HTTP_PORT=9083` into the container, all not overlapping with any other X11 server or container in the same host. Access the container using the specified `NGINX_PORT`.

However, host networking may be restricted or not be desired because of security reasons or when deploying multiple desktop containers in one host. If not available, check if the container starts working after commenting out `hostNetwork: true`.

</details>

- **External TURN Server:**

<details markdown>
  <summary>Open Section</summary>

If having no TURN server does not work, you need an external [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server). Read the [WebRTC and Firewall Issues](#webrtc-and-firewall-issues) section and fill in the environment variables `SELKIES_TURN_HOST` and `SELKIES_TURN_PORT`, then pick one of `SELKIES_TURN_SHARED_SECRET` or both `SELKIES_TURN_USERNAME` and `SELKIES_TURN_PASSWORD` environment variables, based on your authentication method.

</details>

## WebRTC and Firewall Issues

Note that this section is only required for the Selkies WebRTC HTML5 interface.

In most cases when either of your server or client has a permissive firewall, the default Google STUN server configuration will work without additional configuration. However, when connecting from networks that cannot be traversed with STUN, a TURN server is required.

**Read the last steps of each Docker/Kubernetes instruction to use an internal TURN server. Alternatively, read the below sections.**

For an easy fix to when the signaling connection works, but the WebRTC connection fails, **open UDP and TCP ports 49152–65535 in your host server network** (or use Full Cone NAT in your network router/infrastructure settings), then add the option `--network=host` to your Docker command (or `network_mode: 'host'` in `docker-compose.yml`), or uncomment `hostNetwork: true` in your `egl.yml` file when using Kubernetes (note that your cluster may have not allowed this, resulting in an error). This exposes your container to the host network, which disables network isolation. Note that running multiple desktop containers in one host under this configuration may be problematic and is not recommended. You must also pass new environment variables such as `-e DISPLAY=:22`, `-e NGINX_PORT=8082`, `-e SELKIES_PORT=8083`, and `-e SELKIES_METRICS_HTTP_PORT=9083` into the container, all not overlapping with any other X11 server or container in the same host. Access the container using the specified `NGINX_PORT`.

If this does not fix the connection issue (normally when the host is behind another additional firewall), you cannot use this fix for security or technical reasons, or when deploying multiple desktop containers in one host, read the below text to set up an external [TURN server](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server).

### Deploying a TURN server

**Read the instructions from [Selkies](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md#turn-server) if want to deploy an external TURN server or use a public TURN server instance. Read the last steps of each Docker/Kubernetes instruction to use an internal TURN server instead.**

### Configuring with Docker

More information is available in the [Selkies](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md) documentation.

With Docker (or Podman), use the `-e` option to add the `SELKIES_TURN_HOST`, `SELKIES_TURN_PORT` environment variables. This is the hostname or IP and the port of the TURN server (3478 in most cases).

You may set `SELKIES_TURN_PROTOCOL` to `tcp` if you are only able to open TCP ports for the coTURN container to the internet, or if the UDP protocol is blocked or throttled in your client network. You may also set `SELKIES_TURN_TLS` to `true` with the `-e` option if TURN over TLS/DTLS was properly configured with valid TLS certificates.

You also require to provide either only the environment variable `SELKIES_TURN_SHARED_SECRET` for time-limited shared secret TURN authentication, or both the environment variables `SELKIES_TURN_USERNAME` and `SELKIES_TURN_PASSWORD` for legacy long-term TURN authentication, depending on your TURN server configuration. Provide just one of these authentication methods, not both.

If there is a [TURN REST API](https://github.com/selkies-project/selkies/blob/main/docs/component.md#turn-rest) server, provide the environment variable `SELKIES_TURN_REST_URI` but not any other authentication credentials to the TURN REST URI within this infrastructure. If there is a shared TURN server within an infrastructure, consider reading the [TURN REST API](https://github.com/selkies-project/selkies/blob/main/docs/component.md#turn-rest) documentation or provide the link to your infrastructure administrator to deploy a TURN REST API server.

### Configuring with Kubernetes

More information is available in the [Selkies](https://github.com/selkies-project/selkies/blob/main/docs/firewall.md) documentation.

Your TURN server will use only one out of three ways to authenticate the client, so only provide one type of authentication method. The time-limited shared secret TURN authentication only requires the Base64 encoded `SELKIES_TURN_SHARED_SECRET`. The legacy long-term TURN authentication requires both `SELKIES_TURN_USERNAME` and `SELKIES_TURN_PASSWORD` credentials. The [TURN REST API](https://github.com/selkies-project/selkies/blob/main/docs/component.md#turn-rest) method only requires the `SELKIES_TURN_REST_URI` URI.

#### TURN REST API

If there is a shared TURN server within an infrastructure, consider reading the [TURN REST API](https://github.com/selkies-project/selkies/blob/main/docs/component.md#turn-rest) documentation or provide the link to your infrastructure administrator to deploy a TURN REST API server.

<details markdown>
  <summary>Open Section</summary>

Then, uncomment the lines in the `egl.yml` file related to TURN server usage, updating the `SELKIES_TURN_REST_URI` environment variable as needed:

```yaml
- name: SELKIES_TURN_REST_URI
  value: "https://turn-rest.myinfrastructure.io:8443/myturnrest"
- name: SELKIES_TURN_PROTOCOL
  value: "udp"
- name: SELKIES_TURN_TLS
  value: "false"
```

</details>

#### Time-limited shared secret authentication

<details markdown>
  <summary>Open Section</summary>

**1. Create a secret containing the TURN shared secret:**

```bash
kubectl create secret generic turn-shared-secret --from-literal=turn-shared-secret=MY_SELKIES_TURN_SHARED_SECRET
```

> NOTE: Replace `MY_SELKIES_TURN_SHARED_SECRET` with the shared secret of the TURN server, then changing the name `turn-shared-secret` to your preferred name of the Kubernetes secret, with the `egl.yml` file also being changed accordingly.

**2. Uncomment the lines in the `egl.yml` file related to TURN server usage, updating the `SELKIES_TURN_HOST` and `SELKIES_TURN_PORT` environment variables as needed:**

```yaml
- name: SELKIES_TURN_HOST
  value: "turn.example.com"
- name: SELKIES_TURN_PORT
  value: "3478"
- name: SELKIES_TURN_SHARED_SECRET
  valueFrom:
    secretKeyRef:
      name: turn-shared-secret
      key: turn-shared-secret
- name: SELKIES_TURN_PROTOCOL
  value: "udp"
- name: SELKIES_TURN_TLS
  value: "false"
```

> NOTE: It is possible to skip the first step and directly provide the shared secret with `value:`, but this exposes the shared secret in plain text. Set `SELKIES_TURN_PROTOCOL` to `tcp` if you were able to only open TCP ports while creating your own coTURN Deployment/DaemonSet, or if your client network throttles or blocks the UDP protocol at the cost of higher latency and lower performance.

</details>

#### Legacy long-term authentication

<details markdown>
  <summary>Open Section</summary>

**1. Create a secret containing the TURN password:**

```bash
kubectl create secret generic turn-password --from-literal=turn-password=MY_SELKIES_TURN_PASSWORD
```

> NOTE: Replace `MY_SELKIES_TURN_PASSWORD` with the password of the TURN server, then changing the name `turn-password` to your preferred name of the Kubernetes secret, with the `egl.yml` file also being changed accordingly.

**2. Uncomment the lines in the `egl.yml` file related to TURN server usage, updating the `SELKIES_TURN_HOST`, `SELKIES_TURN_PORT`, and `SELKIES_TURN_USERNAME` environment variables as needed:**

```yaml
- name: SELKIES_TURN_HOST
  value: "turn.example.com"
- name: SELKIES_TURN_PORT
  value: "3478"
- name: SELKIES_TURN_USERNAME
  value: "username"
- name: SELKIES_TURN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: turn-password
      key: turn-password
- name: SELKIES_TURN_PROTOCOL
  value: "udp"
- name: SELKIES_TURN_TLS
  value: "false"
```

> NOTE: It is possible to skip the first step and directly provide the TURN password with `value:`, but this exposes the TURN password in plain text. Set `SELKIES_TURN_PROTOCOL` to `tcp` if you were able to only open TCP ports while creating your own coTURN Deployment/DaemonSet, or if your client network throttles or blocks the UDP protocol at the cost of higher latency and lower performance.

</details>

## Troubleshooting

### I have an issue related to the Selkies WebRTC HTML5 interface.

**[Link](https://github.com/selkies-project/selkies/blob/main/docs/README.md)**

### I want to customize this container.

**[Link](https://github.com/selkies-project/selkies/blob/main/docs/development.md)**

### I want to use the keyboard layout of my own language.

<details markdown>
  <summary>Open Answer</summary>

Run `Input Method: Configure Input Method` from the start menu, uncheck `Only Show Current Language`, search and add from available input methods (Hangul, Mozc, Pinyin, and others) by moving to the right, then use `Ctrl + Space` to switch between the input methods. Raise an issue if you need more layouts.

</details>

### The container does not work.

<details markdown>
  <summary>Open Answer</summary>

Check that the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) is properly configured in the host. Next, check that your host NVIDIA GPU driver is not the `nvidia-headless` variant, which lacks the required display and graphics capabilities for this container.

After that, check the environment variable `NVIDIA_DRIVER_CAPABILITIES` after starting a shell interface inside the container. `NVIDIA_DRIVER_CAPABILITIES` should be set to `all`, or include a comma-separated list of `compute` (requirement for CUDA and OpenCL, or for the [Selkies](https://github.com/selkies-project/selkies) WebRTC remote desktop interface), `utility` (requirement for `nvidia-smi` and NVML), `graphics` (requirement for OpenGL and part of the requirement for Vulkan), `video` (required for encoding or decoding videos using NVIDIA GPUs, or for the [Selkies](https://github.com/selkies-project/selkies) WebRTC remote desktop interface), `display` (the other requirement for Vulkan), and optionally `compat32` if you use Wine or 32-bit graphics applications.

Moreover, if you are using custom configurations, check if your shared memory path `/dev/shm` has sufficient capacity, where expanding the capacity is done by adding `--tmpfs /dev/shm:rw` to your Docker command or adding the below lines to your Kubernetes configuration file.

```yaml
spec:
  template:
    spec:
      containers:
        volumeMounts:
        - mountPath: /dev/shm
          name: dshm
      volumes:
      - name: dshm
        emptyDir:
          medium: Memory
```

If you checked everything here, scroll down.

</details>

### I want to use `systemd`, `polkit`, FUSE mounts, or sandboxed (containerized) application distribution systems like Flatpak, Snapcraft (snap), AppImage, Electron, chrome-sandbox, etc.

<details markdown>
  <summary>Open Answer</summary>

**Use the option `--appimage-extract-and-run` or `--appimage-extract` with your AppImage to run them in a container. Alternatively, set `export APPIMAGE_EXTRACT_AND_RUN=1` to your current shell.**

Do not use `systemd`, `polkit`, FUSE mounts, or sandboxed application distribution systems with containers. You can use them if you add unsafe capabilities to your containers, but it will break the isolation of the containers. This is especially bad if you are using Kubernetes. There will likely be an alternative way to install the applications instead of Snapcraft (snap) or Flatpak, including [Personal Package Archives](https://launchpad.net/ubuntu/+ppas). For some applications, there will be options to disable sandboxing when running or options to extract files before running. When applications using Chrome Sandbox (chrome-sandbox) or the [Electron](https://www.electronjs.org/) framework show related errors, use the `--no-sandbox` command-line option when running such applications.

</details>

### OpenGL does not work for certain applications.

<details markdown>
  <summary>Open Answer</summary>

This is likely an issue with [VirtualGL](https://github.com/VirtualGL/virtualgl), which is used to translate GLX commands to EGL commands and use OpenGL without Xorg. Some applications, including research workloads, show this problem. This **cannot** be solved by raising an issue here or contacting me.

First, check that the application works with [docker-selkies-glx-desktop](https://github.com/selkies-project/docker-selkies-glx-desktop) in the same host environment. If it works, it is indeed a problem associated with [VirtualGL](https://github.com/VirtualGL/virtualgl). If it does not, raise an issue here. Second, use the error messages found with verbose mode and search similar issues for your application. Third, if there are no similar issues, raise the issue to the repository or contact the maintainers. Fourth, if the maintainers request that it should be redirected to [VirtualGL](https://github.com/VirtualGL/virtualgl), raise an issue there after confirming [VirtualGL](https://github.com/VirtualGL/virtualgl) does not have similar issues raised. Note that in this case, you may have to wait for a new [VirtualGL](https://github.com/VirtualGL/virtualgl) release and for this repository to use the new release.

</details>

### Vulkan does not work.

<details markdown>
  <summary>Open Answer</summary>

Make sure that the `NVIDIA_DRIVER_CAPABILITIES` environment variable is set to `all`, or includes both `graphics` and `display`. The `display` capability is especially crucial to Vulkan, but the container does start without noticeable issues other than Vulkan without `display`, despite its name. AMD and Intel GPUs are not tested and therefore Vulkan is not guaranteed to work. People are welcome to share their experiences, however.

</details>

### I want to use a specific GPU for OpenGL rendering when I have multiple GPUs in one container.

<details markdown>
  <summary>Open Answer</summary>

Use the `VGL_DISPLAY` environment variable, but only do so after you understand what it implicates with [VirtualGL](https://github.com/VirtualGL/virtualgl). Valid values are either `egl[n]`, or `/dev/dri/card[n]` only when `--device=/dev/dri` was used for the container (`[n]` is the order of the GPUs, where simply `egl` without the number is the same as `egl0`). Note that `docker --gpus 1` means any single GPU, not the GPU device ID of 1. Use `docker --gpus '"device=1,2"'` to provision GPUs with device IDs 1 and 2 to the container.

</details>

---
This project has been developed and is supported in part by the National Research Platform (NRP) and the Cognitive Hardware and Software Ecosystem Community Infrastructure (CHASE-CI) at the University of California, San Diego, by funding from the National Science Foundation (NSF), with awards #1730158, #1540112, #1541349, #1826967, #2138811, #2112167, #2100237, and #2120019, as well as additional funding from community partners, infrastructure utilization from the Open Science Grid Consortium, supported by the National Science Foundation (NSF) awards #1836650 and #2030508, and infrastructure utilization from the Chameleon testbed, supported by the National Science Foundation (NSF) awards #1419152, #1743354, and #2027170. This project has also been funded by the Seok-San Yonsei Medical Scientist Training Program (MSTP) Song Yong-Sang Scholarship, College of Medicine, Yonsei University, the MD-PhD/Medical Scientist Training Program (MSTP) through the Korea Health Industry Development Institute (KHIDI), funded by the Ministry of Health & Welfare, Republic of Korea, and the Student Research Bursary of Song-dang Institute for Cancer Research, College of Medicine, Yonsei University.
