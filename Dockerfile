FROM gentoo/stage3:amd64-openrc

ARG KVER=6.6.21
ARG TARGET=bootx64.efi

RUN emerge-webrsync && echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf && \
    echo 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox"' >> /etc/portage/make.conf && \
    echo 'USE="${USE} symlink -firmware lzo lzma zstd"' >> /etc/portage/make.conf && \
    echo "dev-util/github-cli **" > /etc/portage/package.accept_keywords/github-cli && \
    emerge -vq genkernel gentoo-sources:$KVER github-cli squashfs-tools p7zip

RUN curl -L https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import && \
    curl -L "https://distfiles.gentoo.org/releases/amd64/autobuilds/current-install-amd64-minimal/latest-install-amd64-minimal.txt" | gpg --verify -o - | grep iso | awk '{print "https://distfiles.gentoo.org/releases/amd64/autobuilds/current-install-amd64-minimal/" $1}' | xargs curl -L -o /tmp/install-minimal.iso && \
    7z x /tmp/install-minimal.iso image.squashfs && \
    rm -f /tmp/install-minimal.iso && \
    unsquashfs -excludes image.squashfs 'lib/firmware/qcom/*' && \
    rm -f image.squashfs && \
    mkdir -p /tmp/overlay && \
    mksquashfs squashfs-root /tmp/overlay/image.squashfs -noappend -comp xz && \
    rm -rf squashfs-root

RUN curl -L https://raw.githubusercontent.com/gentoo/releng/master/releases/kconfig/amd64/amd64-6.6.13.config -o /usr/src/linux/.config && \
    sed -i 's/# CONFIG_CMDLINE_BOOL is not set/CONFIG_CMDLINE_BOOL=y/' /usr/src/linux/.config && \
    echo 'CONFIG_CMDLINE="root=/dev/ram0 init=/linuxrc overlayfs nodhcp looptype=squashfs loop=/image.squashfs cdroot"' >> /usr/src/linux/.config && \
    sed -i 's/#ALLRAMDISKMODULES="no"/ALLRAMDISKMODULES="yes"/' /etc/genkernel.conf && \
    sed -i 's/#MOUNTBOOT="yes"/MOUNTBOOT="no"/' /etc/genkernel.conf && \
    sed -i 's/#INTEGRATED_INITRAMFS="no"/INTEGRATED_INITRAMFS="yes"/' /etc/genkernel.conf && \
    sed -i 's/#INITRAMFS_OVERLAY=""/INITRAMFS_OVERLAY="\/tmp\/overlay"/' /etc/genkernel.conf && \
    sed -i 's/#COMPRESS_INITRD_TYPE="best"/COMPRESS_INITRD_TYPE="xz"/' /etc/genkernel.conf

RUN genkernel all --oldconfig --kernel-filename=$TARGET --install

ARG GH_TOKEN
ARG REPO
ARG REF

RUN gh repo clone $REPO /git -- -b $REF && cd /git && \
    gh release create $REF --notes "kernel version $KVER" "/boot/${TARGET}#${TARGET}" "/boot/${TARGET}#bootia32.efi"
