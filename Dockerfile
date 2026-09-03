# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# KDE Plasma desktop container for Selkies: the desktop environment on top of
# the Selkies base container (ghcr.io/selkies-project/selkies/base).
#
# The base is the whole session apart from what it looks like -- the X11
# framebuffer server and the headless Wayland backend, audio, GPU wiring, s6,
# coTURN and Selkies itself. This layer adds only the desktop: Plasma on the
# base's Xvfb by default and natively on a nested kwin_wayland under
# SELKIES_WAYLAND=true, the browsers, and the proot-apps runner behind the
# dashboards' apps panel. The GPU is reached the way the base reaches it, through
# EGL and DRI3 with no X.Org server of its own, so one GPU serves as many of
# these containers as it has memory for; docker-selkies-glx-desktop runs the
# same desktop on an X.Org server that owns the GPU instead.
#
# A second display on the Wayland backend is a kwin virtual output, which the
# nested backend of the distribution's kwin never registers: kwin-wayland is
# rebuilt from the archive source with the patches under patches/. The rebuilt
# packages are the archive's exact version, so this image is Ubuntu 26.04
# only and the base it is built on must be the Ubuntu one.

ARG BASE_IMAGE="ghcr.io/selkies-project/selkies/base:main-ubuntu26.04"
ARG DISTRIB_IMAGE="ubuntu"
ARG DISTRIB_RELEASE="26.04"
# The Selkies revision the shared helper scripts are taken from
ARG SELKIES_REF="main"

# The distribution kwin, rebuilt with the Selkies patches. Built on the plain
# distribution image rather than the Selkies base: the archive and toolchain
# are the same, and a throwaway root stage needs none of the base's rootless
# arrangements. It rebuilds whatever kwin version the archive serves, which is
# also the version the desktop layer below installs.
FROM ${DISTRIB_IMAGE}:${DISTRIB_RELEASE} AS kwinbuild
ARG DEBIAN_FRONTEND="noninteractive"
RUN printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\nAcquire::Retries::Delay::Maximum "30";\n' \
        > /etc/apt/apt.conf.d/99-selkies-retries
COPY patches/kwin/ /build/patches/
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get clean && apt-get update && \
    apt-get install --no-install-recommends -y \
        ca-certificates \
        dpkg-dev && \
    apt-get build-dep -y kwin && \
    mkdir -p /build/src && cd /build/src && \
    apt-get source kwin && \
    cd kwin-*/ && \
    for kwin_patch in /build/patches/*.patch; do patch -p1 < "${kwin_patch}"; done && \
    DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" \
        dpkg-buildpackage -b -uc -us && \
    mkdir -p /build/debs && \
    mv /build/src/*.deb /build/debs/

# The X11 window manager, rebuilt the same way: stock kwin_x11 makes one screen
# per CRTC and spans the displays Selkies publishes as RandR monitors over the
# one CRTC a framebuffer server has, so a maximized window would cover both.
FROM ${DISTRIB_IMAGE}:${DISTRIB_RELEASE} AS kwinx11build
ARG DEBIAN_FRONTEND="noninteractive"
RUN printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\nAcquire::Retries::Delay::Maximum "30";\n' \
        > /etc/apt/apt.conf.d/99-selkies-retries
COPY patches/kwin-x11/ /build/patches/
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get clean && apt-get update && \
    apt-get install --no-install-recommends -y \
        ca-certificates \
        dpkg-dev && \
    apt-get build-dep -y kwin-x11 && \
    mkdir -p /build/src && cd /build/src && \
    apt-get source kwin-x11 && \
    cd kwin-x11-*/ && \
    for kwin_patch in /build/patches/*.patch; do patch -p1 < "${kwin_patch}"; done && \
    DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" \
        dpkg-buildpackage -b -uc -us && \
    mkdir -p /build/debs && \
    mv /build/src/*.deb /build/debs/

FROM ${BASE_IMAGE}

LABEL maintainer="https://github.com/danisla,https://github.com/ehfd"
LABEL org.opencontainers.image.title="Selkies EGL Desktop Container"
LABEL org.opencontainers.image.description="KDE Plasma desktop on the Selkies base container: Plasma on X11 (Xvfb) by default and natively on headless Wayland (nested kwin) with SELKIES_WAYLAND=true, the GPU reached through EGL with no X.Org server of its own, s6 service supervision, embedded coTURN. Ubuntu 26.04 base only."
LABEL org.opencontainers.image.source="https://github.com/selkies-project/docker-selkies-egl-desktop"
LABEL org.opencontainers.image.licenses="MPL-2.0"

ARG DEBIAN_FRONTEND="noninteractive"
ARG SELKIES_REF

# The base ships its setuid and setgid files owned by root, and dpkg replaces a
# file by hardlinking the old one aside first -- which the kernel denies uid
# 1000 on a setuid file it does not own. Released for the layers below, an
# archive update to util-linux, shadow, sudo, fuse3 or dbus is just another
# package; without this it fails the layer that takes it. The helper is the
# base's own; a base published before it carried one is given the copy the
# Selkies repository ships.
USER 0
SHELL ["/bin/sh", "-c"]
RUN if ! command -v selkies-privileged-files > /dev/null; then \
        curl -o /usr/local/bin/selkies-privileged-files -fsSL --retry 5 --retry-delay 3 --retry-connrefused --retry-max-time 180 \
            "https://raw.githubusercontent.com/selkies-project/selkies/${SELKIES_REF}/addons/base/selkies-privileged-files" && \
        chown 1000:1000 /usr/local/bin/selkies-privileged-files && chmod 755 /usr/local/bin/selkies-privileged-files; \
    fi && \
    selkies-privileged-files release

# Rootless like the base: layers run as the session user through fakeroot, so
# the package database and apt cache stay owned by that user and in-session
# package management behaves like `/usr/bin/sudo` (the fakeroot alias) does at
# runtime. Real-root operations in the live session use /usr/bin/sudo-root.
USER 1000
SHELL ["/usr/bin/fakeroot", "--", "/bin/sh", "-c"]

COPY --from=kwinbuild --chown=1000:1000 /build/debs /tmp/kwin-debs
COPY --from=kwinx11build --chown=1000:1000 /build/debs /tmp/kwin-x11-debs

# The Plasma desktop, then the patched kwin and kwin-x11 over the packaged ones
# in the same operation. Both session launchers are installed: startplasma-x11
# with kwin_x11 for the base's Xvfb, startplasma-wayland with kwin_wayland for
# the nested session. The dpkg -i takes only the rebuilt debs whose package the
# install above put on the system (kwin-common, kwin-data, kwin-wayland,
# kwin-x11 -- not the debug or development splits), in one invocation so dpkg
# orders them itself.
RUN apt-get clean && apt-get update && apt-get install --no-install-recommends -y \
        plasma-desktop \
        plasma-workspace \
        plasma-session-x11 \
        plasma-session-wayland \
        kwin-x11 \
        kwin-wayland \
        # Recommends of the packages above that a session is expected to
        # provide: the theme, the GTK bridge, the PolicyKit agent, the portal
        # backend applications open files and share screens through, the
        # tools KDE launches by name, the system monitor the panel reads
        breeze \
        breeze-gtk-theme \
        breeze-icon-theme \
        kde-config-gtk-style \
        polkit-kde-agent-1 \
        xdg-desktop-portal-kde \
        kde-cli-tools \
        kio-extras \
        ksystemstats \
        systemsettings \
        # The applications a desktop is unusable without: file manager,
        # terminal, editor, image viewer, archiver, dialogs for scripts, the
        # volume applet the panel loads and the system monitor it links to
        dolphin \
        konsole \
        kwrite \
        gwenview \
        ark \
        kdialog \
        plasma-pa \
        plasma-systemmonitor \
        # Image formats past what Qt reads on its own (WebP, TIFF, AVIF, HEIF),
        # which a clipboard image or a download arrives as
        kimageformat6-plugins \
        qt6-image-formats-plugins \
        # proot-apps refreshes the icon cache of the theme it installs into by
        # calling gtk-update-icon-cache; without it that refresh is a silent
        # no-op and the cache a session reads predates the application
        gtk-update-icon-cache && \
    debs="" && \
    for deb in /tmp/kwin-debs/*.deb /tmp/kwin-x11-debs/*.deb; do \
        if dpkg -s "$(dpkg-deb -f "${deb}" Package)" > /dev/null 2>&1; then \
            debs="${debs} ${deb}"; \
        fi; \
    done && \
    dpkg -i ${debs} && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# Session defaults in the system scope, so a user's own settings still win:
# no splash on a streamed desktop, no lock screen (a locked container session
# has no local seat to unlock it) and no leave actions (logging out ends the
# session the stream is showing, and shutdown addresses an init this container
# does not run), no compositing on the X11 session (every animation is
# bandwidth for nothing, and the framebuffer server renders it in software),
# and no file indexing of a container home.
RUN mkdir -pm755 /etc/xdg && \
    printf '[KSplash]\nEngine=none\n' > /etc/xdg/ksplashrc && \
    printf '[Daemon]\nAutolock=false\nLockOnResume=false\n' > /etc/xdg/kscreenlockerrc && \
    printf '[KDE Action Restrictions]\naction/lock_screen=false\naction/switch_user=false\nlogout=false\n\n[General]\nBrowserApplication=firefox.desktop\n' > /etc/xdg/kdeglobals && \
    printf '[Compositing]\nEnabled=false\n' > /etc/xdg/kwinrc && \
    printf '[Basic Settings]\nIndexing-Enabled=false\n' > /etc/xdg/baloofilerc && \
    # Plasma's device notifier and Dolphin's places poll UDisks2, which the
    # session bus cannot activate here (a container mounts nothing) and would
    # otherwise retry, and log, on every query; without the activation file
    # the service is simply absent
    rm -f /usr/share/dbus-1/system-services/org.freedesktop.UDisks2.service

# The browsers, in one apt operation: Firefox from Mozilla's own APT repository,
# which serves real .deb builds and is pinned over the distribution package, and
# Google Chrome as a downloaded .deb for the H.264/AV1 media stack the
# distribution Chromium builds do not carry. Chrome's own launcher script gains
# two switches, so every way of starting it -- menu entry, xdg-open, a shell --
# carries them: --no-sandbox, because Chrome's sandbox needs CAP_SYS_ADMIN for
# its setuid helper or unprivileged user namespaces for its zygote, and a
# container's default seccomp profile grants neither, so a stock Chrome aborts
# at the zygote (the container is the isolation boundary here); and the basic
# password store, because the container runs no keyring daemon to unlock and
# Chrome otherwise blocks on a prompt nobody can answer. The downloads retry
# every failure and the Chrome one is held to HTTP/1.1, since its server resets
# HTTP/2 streams mid-transfer often enough to fail a build.
RUN mkdir -pm755 /etc/apt/keyrings /etc/apt/sources.list.d /etc/apt/preferences.d && \
    curl -o /etc/apt/keyrings/packages.mozilla.org.asc -fsSL --retry 5 --retry-all-errors --retry-delay 3 --retry-connrefused --retry-max-time 180 "https://packages.mozilla.org/apt/repo-signing-key.gpg" && \
    printf 'Types: deb\nURIs: https://packages.mozilla.org/apt\nSuites: mozilla\nComponents: main\nSigned-By: /etc/apt/keyrings/packages.mozilla.org.asc\n' > /etc/apt/sources.list.d/mozilla.sources && \
    printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla && \
    curl -o /tmp/google-chrome-stable.deb -fsSL --http1.1 --retry 5 --retry-all-errors --retry-delay 3 --retry-connrefused --retry-max-time 180 "https://dl.google.com/linux/direct/google-chrome-stable_current_$(dpkg --print-architecture).deb" && \
    apt-get clean && apt-get update && \
    apt-get install --no-install-recommends -y firefox /tmp/google-chrome-stable.deb && \
    sed -i 's|^exec -a "$0" "$HERE/chrome" "$@"$|exec -a "$0" "$HERE/chrome" --no-sandbox --password-store=basic "$@"|' /opt/google/chrome/google-chrome && \
    grep -q -- '--no-sandbox --password-store=basic "$@"' /opt/google/chrome/google-chrome && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# proot-apps (https://github.com/linuxserver/proot-apps) backs the dashboards'
# apps panel: portable per-user applications in a proot, installed and removed
# through the selkies-proot wrapper without touching the image. The release
# tarball is staged here and linked into each user's ~/.local/bin, because
# proot-apps runs its tools from there by absolute path. proot traces every
# process it starts, so a second copy carries CAP_SYS_PTRACE for the hosts that
# restrict ptrace; it is kept apart because a file capability the container's
# bounding set does not hold stops that binary from execing at all, and the
# wrapper picks whichever of the two runs. The wrapper is the one the Selkies
# desktop container ships, taken from the same revision as the base.
RUN mkdir -pm755 /opt/proot-apps && \
    PAPPS_RELEASE="$(curl -fsSL --retry 5 --retry-delay 3 --retry-connrefused --retry-max-time 180 -o /dev/null -w '%{url_effective}' "https://github.com/linuxserver/proot-apps/releases/latest" | sed 's|.*/||')" && \
    curl -fsSL --retry 5 --retry-delay 3 --retry-connrefused --retry-max-time 180 "https://github.com/linuxserver/proot-apps/releases/download/${PAPPS_RELEASE}/proot-apps-$(dpkg --print-architecture | sed 's/amd64/x86_64/;s/arm64/aarch64/').tar.gz" \
        | tar -xzf - -C /opt/proot-apps/ && \
    printf '%s\n' "${PAPPS_RELEASE}" > /opt/proot-apps/pversion && \
    if ! command -v setcap > /dev/null; then \
        apt-get update && apt-get install --no-install-recommends -y libcap2-bin && \
        apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*; \
    fi && \
    mkdir -pm755 /opt/proot-apps-cap && \
    cp /opt/proot-apps/proot /opt/proot-apps-cap/proot && \
    setcap cap_sys_ptrace+ep /opt/proot-apps-cap/proot && \
    curl -o /usr/local/bin/selkies-proot -fsSL --retry 5 --retry-delay 3 --retry-connrefused --retry-max-time 180 \
        "https://raw.githubusercontent.com/selkies-project/selkies/${SELKIES_REF}/addons/desktop/selkies-proot" && \
    chmod -f 755 /usr/local/bin/selkies-proot

# The session compositor the base's wayland service execs
# (SELKIES_WAYLAND_COMPOSITOR below), and the session's own s6 services --
# the Plasma X11 session and the session bus every part of Plasma meets on --
# supervised beside the base container's.
COPY --chown=1000:1000 selkies-kwin /usr/local/bin/selkies-kwin
COPY --chown=1000:1000 services/ /etc/service/
RUN chmod -f 755 /usr/local/bin/selkies-kwin && \
    find /etc/service \( -name run -o -name finish \) -exec chmod -f 755 {} +

RUN printf "==============================================\n=         Selkies EGL Desktop Container      =\n==============================================\n" > /etc/motd

USER 0
# Real root for the same reason the base needs it: under the fakeroot SHELL an
# ownership change lands only in fakeroot's database, leaving a setuid bit on a
# file owned by uid 1000, which the kernel refuses to honour. The PolicyKit
# agent helper and pkexec need theirs to authenticate at all, and a terminal's
# utempter its setgid to record sessions. `restore` covers everything released
# above, which is the base's own set rather than these.
SHELL ["/bin/sh", "-c"]
RUN selkies-privileged-files restore && \
    for helper in /usr/lib/polkit-1/polkit-agent-helper-1 /usr/libexec/polkit-agent-helper-1 /usr/bin/pkexec; do \
        if [ -e "$helper" ]; then chown -f root:root "$helper" && chmod -f 4755 "$helper" || echo "Failed to restore setuid for $helper"; fi; \
    done && \
    for helper in /usr/lib/*/utempter/utempter /usr/libexec/utempter/utempter; do \
        if [ -e "$helper" ]; then chown -f root:utmp "$helper" && chmod -f 2755 "$helper" || echo "Failed to restore setgid for $helper"; fi; \
    done

USER 1000

# The dashboards' apps panel drives proot-apps through the command channel;
# without this the server tells clients the panel is unusable and they drop it.
# Commands run as the session user, whom the streamed desktop already hands a
# terminal, so the desktop image enables the channel; disable with
# -e SELKIES_COMMAND_ENABLED=false.
ENV SELKIES_COMMAND_ENABLED="true"
# Start the Plasma session (set to false to run only the display server, or
# only kwin on the Wayland backend)
ENV START_PLASMA="true"
# The Plasma session is the nested compositor the base's wayland service
# starts: selkies-kwin runs startplasma-wayland, whose kwin_wayland nests
# inside the capture compositor
ENV SELKIES_WAYLAND_COMPOSITOR="selkies-kwin"
# Plasma's menu definitions carry its prefix; the base defaults to lxqt-
ENV XDG_MENU_PREFIX="plasma-"
# Second displays on the Wayland backend are kwin virtual outputs, which the
# patched kwin this image ships registers; the interface has to stay visible
# to Selkies (kwin hides it from clients without an X-KDE-Wayland-Interfaces
# desktop entry, a check a python process can never satisfy).
ENV KWIN_WAYLAND_NO_PERMISSION_CHECKS="1"
