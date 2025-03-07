FROM debian:sid as builder
MAINTAINER Bo YU "tsu.yubo@gmail.com"

ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,sharing=shared,target=/var/cache \
    --mount=type=cache,sharing=shared,target=/var/lib/apt/lists \
    --mount=type=tmpfs,target=/usr/share/man \
    --mount=type=tmpfs,target=/usr/share/doc \
    apt-get update \
    && apt-get install -y eatmydata \
    && eatmydata apt-get install -y qemu-user-static \
        binfmt-support gdisk kpartx \
        parted \
        autoconf automake autotools-dev bc \
        build-essential cpio curl \
        dosfstools e2fsprogs fdisk flex gawk  \
        git gperf kmod libexpat-dev \
        libgmp-dev libmpc-dev libmpfr-dev libssl-dev \
        libtool mmdebstrap openssl parted \
        patchutils python3 python3-dev \
        python3-setuptools qemu-user-static swig \
        systemd-container texinfo zlib1g-dev wget \
    &&  update-binfmts --enable qemu-riscv64 \
    && mmdebstrap --architectures=riscv64 \
    --include="debian-archive-keyring linux-image-riscv64 u-boot-menu u-boot-sifive" \
    sid /tmp/riscv64-chroot \
    "deb http://deb.debian.org/debian sid main contrib non-free non-free-firmware"

# build rootfs 
#FROM builder as build_rootfs
#WORKDIR /build

#COPY rootfs/multistrap_nvme.conf multistrap.conf

#RUN --mount=type=cache,sharing=shared,target=/var/cache \
#    --mount=type=cache,sharing=shared,target=/var/lib/apt/lists \
#    --mount=type=tmpfs,target=/usr/share/man \
#    --mount=type=tmpfs,target=/usr/share/doc \
#    eatmydata multistrap -f multistrap.conf
# /port/rv64-port this is dest

FROM builder as build_image
WORKDIR /builder
COPY --from=builder /tmp/riscv64-chroot ./rv64-port/
COPY create_image.sh build.sh ./
COPY after_mkrootfs.sh ./
# debug
#RUN sleep infinity

CMD /builder/build.sh

