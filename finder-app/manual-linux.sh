

#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-
WORKING_DIR=$(pwd)

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
else
	cd ${OUTDIR}/linux-stable
    	echo "LINUX STABLE DIRECTORY ALREADY EXISTS"
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd ${OUTDIR}/linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

#from jaeseolee, thanks!#
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j4 ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} scripts
    make -j4 ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs
fi

echo "Adding the Image in outdir"
cd "$OUTDIR"
cp linux-stable/arch/arm64/boot/Image "$OUTDIR/"


echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

mkdir -p ${OUTDIR}/rootfs/{bin,dev,home,tmp,lib,lib64,sbin,etc,proc,sys,var/log,usr/{bin,lib,sbin}}


cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    
   #Make and install busybox
   
    sudo make distclean
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc)
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install
    
else
    echo "BusyBox directory already exists, skipping clone..."
    cd busybox
    make distclean
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc)
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install
  
fi



echo "Library dependencies"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library"

#Add library dependencies to rootfs


SYSROOT=$(aarch64-none-linux-gnu-gcc --print-sysroot)

# Copy the necessary libraries to the rootfs lib directory
sudo cp -P ${SYSROOT}/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/
sudo cp -P ${SYSROOT}/lib64/libc.so.6 ${OUTDIR}/rootfs/lib64/
sudo cp -P ${SYSROOT}/lib64/libm.so.6 ${OUTDIR}/rootfs/lib64/
sudo cp -P ${SYSROOT}/lib64/libresolv.so.2 ${OUTDIR}/rootfs/lib64/


#make device nodes
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/tty c 5 0
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/zero c 1 5
sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1

cd $WORKING_DIR
sudo make clean
make CROSS_COMPILE=aarch64-none-linux-gnu-



#Copy the finder related scripts and executables 
cp $FINDER_APP_DIR/finder.sh ${OUTDIR}/rootfs/home
cp $FINDER_APP_DIR/../conf/username.txt ${OUTDIR}/rootfs/home
cp $FINDER_APP_DIR/../conf/assignment.txt ${OUTDIR}/rootfs/home
cp $FINDER_APP_DIR/finder-test.sh ${OUTDIR}/rootfs/home
cp writer ${OUTDIR}/rootfs/home

# Modify finder-test.sh to reference conf/assignment.txt correctly
sed -i 's|\.\./conf/assignment.txt|conf/assignment.txt|g' ${OUTDIR}/rootfs/home/finder-test.sh



echo "Copying autorun-qemu.sh to the rootfs"
cp ${FINDER_APP_DIR}/autorun-qemu.sh ${OUTDIR}/rootfs/home/


#Chown the root directory
cd ${OUTDIR}/rootfs
sudo chown -R root:root ${OUTDIR}/rootfs

#Create initramfs.cpio.gz
cd ${OUTDIR}/rootfs
sudo find . | sudo cpio -H newc -ov --owner root:root > ../initramfs.cpio
cd "$OUTDIR"
gzip -f initramfs.cpio
echo "finished"
#find . | cpio -H newc -o | gzip > ${OUTDIR}/initramfs.cpio.gz









