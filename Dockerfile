FROM gentoo/stage3:i686-openrc

ARG KVER=6.6.13
ARG TARGET=bootia32.efi

RUN emerge-webrsync && echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf && \
    echo 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox"' >> /etc/portage/make.conf && \
    echo 'USE="symlink -firmware"' >> /etc/portage/make.conf && \
    echo "dev-util/github-cli **" > /etc/portage/package.accept_keywords/github-cli && \
    emerge -vq genkernel gentoo-sources:$KVER p7zip github-cli

RUN curl -L https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import && \
    curl -L "https://distfiles.gentoo.org/releases/x86/autobuilds/current-install-x86-minimal/latest-install-x86-minimal.txt" | gpg --verify -o - | grep iso | awk '{print "https://distfiles.gentoo.org/releases/x86/autobuilds/current-install-x86-minimal/" $1}' | xargs curl -L -o /tmp/install-minimal.iso && \
    mkdir -p /tmp/overlay && cd /tmp/overlay && \
    7z x /tmp/install-minimal.iso image.squashfs && \
    rm -f /tmp/install-minimal.iso

RUN curl -L https://raw.githubusercontent.com/gentoo/releng/master/releases/kconfig/x86/x86-5.4.38.config -o /usr/src/linux/.config && \
    sed -i 's/# CONFIG_CMDLINE_BOOL is not set/CONFIG_CMDLINE_BOOL=y/' /usr/src/linux/.config && \
    echo 'CONFIG_CMDLINE="root=/dev/ram0 init=/linuxrc overlayfs nodhcp looptype=squashfs loop=/image.squashfs cdroot"' >> /usr/src/linux/.config && \
    sed -i 's/# CONFIG_EFI_STUB is not set/CONFIG_EFI_STUB=y/' /usr/src/linux/.config && \
    sed -i 's/#ALLRAMDISKMODULES="no"/ALLRAMDISKMODULES="yes"/' /etc/genkernel.conf && \
    sed -i 's/#MOUNTBOOT="yes"/MOUNTBOOT="no"/' /etc/genkernel.conf && \
    sed -i 's/#INTEGRATED_INITRAMFS="no"/INTEGRATED_INITRAMFS="yes"/' /etc/genkernel.conf && \
    sed -i 's/#INITRAMFS_OVERLAY=""/INITRAMFS_OVERLAY="\/tmp\/overlay"/' /etc/genkernel.conf && \
    sed -i 's/#KERNEL_LOCALVERSION="-%%ARCH%%"/KERNEL_LOCALVERSION=""/' /etc/genkernel.conf && \
    sed -i 's/#CROSS_COMPILE=""/CROSS_COMPILE="i686-pc-linux-gnu"/' /etc/genkernel.conf

RUN genkernel all --oldconfig --kernel-filename=$TARGET --install

ARG GH_TOKEN
ARG REPO
ARG REF

RUN gh repo clone $REPO /git -- -b $REF && cd /git && \
    gh release create $REF --notes "kernel version $KVER" "/boot/${TARGET}#${TARGET}"
