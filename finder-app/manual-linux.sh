#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # Adding kernel build steps here

    # QEMU build - clean: deep clean the kernel build tree - removing the .config file with any existing configuration
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper

    # QEMU build - defconfig: configure for our "virt" arm dev board we will simulate in QEMU
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig

    # QEMU build - vmlinux : build a kernel image for booting with QEMU
    make -j4 ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all

    # QEMU build - modules and devicetree
    #    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules
    #    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs
fi

echo "Adding the Image in outdir"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
  sudo rm  -rf ${OUTDIR}/rootfs
fi

# Creating necessary base directories
for dir in bin dev etc home lib lib64 proc sbin sys tmp usr var usr/bin usr/lib usr/sbin var/log; do
  mkdir -p "${OUTDIR}/rootfs/${dir}"
done

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
else
    cd busybox
fi

# Making and installing busybox
make distclean
make defconfig
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
make CONFIG_PREFIX="$OUTDIR/rootfs" ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

echo "Library dependencies"
${CROSS_COMPILE}readelf -a "$OUTDIR/rootfs/bin/busybox" | grep "program interpreter"
${CROSS_COMPILE}readelf -a "$OUTDIR/rootfs/bin/busybox" | grep "Shared library"

# Adding library dependencies to rootfs
cp "$(dirname $(which ${CROSS_COMPILE}gcc))/../aarch64-none-linux-gnu/libc/lib/ld-linux-aarch64.so.1" \
  "$OUTDIR/rootfs/lib/"
cp "$(dirname $(which ${CROSS_COMPILE}gcc))/../aarch64-none-linux-gnu/libc/lib64/libm.so.6" \
  "$OUTDIR/rootfs/lib64/"
cp "$(dirname $(which ${CROSS_COMPILE}gcc))/../aarch64-none-linux-gnu/libc/lib64/libresolv.so.2" \
  "$OUTDIR/rootfs/lib64/"
cp "$(dirname $(which ${CROSS_COMPILE}gcc))/../aarch64-none-linux-gnu/libc/lib64/libc.so.6" \
  "$OUTDIR/rootfs/lib64/"


# Making device nodes
sudo mknod -m 666 "$OUTDIR/rootfs/dev/null" c 1 3
sudo mknod -m 666 "$OUTDIR/rootfs/dev/console" c 5 1

# TODO: Clean and build the writer utility
make -C "${FINDER_APP_DIR}/" clean
make -C "${FINDER_APP_DIR}/"

# Copying the finder related scripts and executables to the /home directory
# on the target rootfs
cp "${FINDER_APP_DIR}/writer" "$OUTDIR/rootfs/home/"

# Changing ownership of root directory
sudo chown -R root:root "$OUTDIR/rootfs/"

# Creating initramfs.cpio.gz
cd "$OUTDIR/rootfs/"
find . | cpio -H newC -ov --owner root:root > "${OUTDIR}/initramfs.cpio"
gzip -f "${OUTDIR}/initramfs.cpio"
