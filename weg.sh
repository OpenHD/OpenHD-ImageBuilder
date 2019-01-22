#!/bin/bash

# apt dependencies: qemu qemu-user-static binfmt-support

set -e
# Extreme logging off for quieter experience
# set -o xtrace

# Switch to lite? http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2018-06-29/2018-06-27-raspbian-stretch-lite.zip
#BASE_IMAGE_URL="http://downloads.raspberrypi.org/raspbian/images/raspbian-2018-06-29"
#BASE_IMAGE="2018-06-27-raspbian-stretch"

# Latest image
BASE_IMAGE_URL="http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2018-10-11"
BASE_IMAGE="2018-10-09-raspbian-stretch-lite"


DATA_DIR="$PWD/data"
MNT_DIR="$DATA_DIR/mnt"
GIT_DIR="$DATA_DIR/git"
KERNEL_DIR="$DATA_DIR/kernel"
KERNEL_PATCHES="$PWD/kernel_patches/*.patch"


function download_image {
	#first, download raspian image
	pushd $PWD
	cd data

	if [ ! -f $BASE_IMAGE".img" ]
	then
		if [ ! -f $BASE_IMAGE".zip" ]
		then
			wget $BASE_IMAGE_URL/$BASE_IMAGE".zip"
		fi
		unzip $BASE_IMAGE".zip"

		# Magically enlarge the disk
		source ../increasesize.sh
	fi

	popd
}

function download_kernel_and_tools {
	pushd $PWD

	mkdir -p "$KERNEL_DIR"
	cd "$KERNEL_DIR"

	if [ ! -d ~/tools ]
	then
		git clone https://github.com/raspberrypi/tools ~/tools
		echo PATH=\$PATH:~/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian/bin >> ~/.bashrc
		source ~/.bashrc
	fi

	if [ ! -d linux ]
	then
		git clone --depth=1 https://github.com/raspberrypi/linux
	fi

	#revert any previous changes, so that any patches can be applied flawlessly
	cd linux
	git checkout .
	
	cd ..

	if [ ! -d linux7 ]
	then
		# duplicate the source tree
		sudo cp -R linux linux7/
	fi
	
	cd linux7
	git checkout .
	
	cd ..

	popd
}

function patch_kernel {
	pushd $PWD
	cd "$KERNEL_DIR/linux"

	for f in $KERNEL_PATCHES
	do
		echo "Applying patch $f"
		patch -N -p1 < $f
	done

	popd
}

function patch_kernel7 {
	pushd $PWD
	cd "$KERNEL_DIR/linux7"

	for f in $KERNEL_PATCHES
	do
		echo "Applying patch $f"
		patch -N -p1 < $f
	done

	popd
}

function compile_kernel {	
	pushd $PWD
	cd "$KERNEL_DIR/linux"

	KERNEL=kernel ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make bcmrpi_defconfig
	KERNEL=kernel ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j4 zImage modules dtbs

	popd
}

function compile_kernel7 {	
	pushd $PWD
	cd "$KERNEL_DIR/linux7"

	KERNEL=kernel7 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make bcm2709_defconfig
	KERNEL=kernel7 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j4 zImage modules dtbs

	popd
}

#args: fat-partition, ext4-partition
function install_kernel {
	pushd $PWD

	cd "$KERNEL_DIR/linux"

	#install modules 
	sudo make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH="$2" modules_install
	
	# install kernel and fdt for Pi 1, Pi 0, Pi 0 W, or Compute Module
	# mkknlimg no longer needed it seems
	#sudo cp "$1/kernel.img" "$1/kernel-backup.img"
	sudo cp arch/arm/boot/zImage "$1/kernel.img"
	sudo cp arch/arm/boot/dts/*.dtb "$1/"
	sudo cp arch/arm/boot/dts/overlays/*.dtb* "$1/overlays/"
	sudo cp arch/arm/boot/dts/overlays/README "$1/overlays/"

	#sudo scripts/mkknlimg arch/arm/boot/zImage "$1/kernel.img"
	#sudo cp arch/arm/boot/dts/*.dtb "$1"
	#sudo cp arch/arm/boot/dts/overlays/*.dtb* "$1/overlays"
	#sudo cp arch/arm/boot/dts/overlays/README "$1/overlays"

	# And the kernel for the Pi 2, Pi 3, Pi 3+, or Compute Module 3 version
	cd "$KERNEL_DIR/linux7"

	#install modules 
	sudo make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH="$2" modules_install
	
	# install kernel and fdt for Pi 1, Pi 0, Pi 0 W, or Compute Module
	# mkknlimg no longer needed it seems
	#sudo cp "$1/kernel7.img" "$1/kernel7-backup.img"
	sudo cp arch/arm/boot/zImage "$1/kernel7.img"
	sudo cp arch/arm/boot/dts/*.dtb "$1/"
	sudo cp arch/arm/boot/dts/overlays/*.dtb* "$1/overlays/"
	sudo cp arch/arm/boot/dts/overlays/README "$1/overlays/"

	popd
}

function create_git_structure {
	pushd $PWD

	sudo git config --global url."https://github.com/".insteadOf git@github.com:
	sudo git config --global url."https://".insteadOf git://

	if [ -d "$GIT_DIR" ]
	then
		rm -r "$GIT_DIR"
	fi

	mkdir -p "$GIT_DIR"

	cd "$GIT_DIR"

	# custom repository for modified openvg library
	sudo git clone https://github.com/RespawnDespair/openvg-font.git openvg
	
	sudo git clone -b rock64 https://github.com/estechnical/mavlink-router.git
		
	cd mavlink-router
	sudo git submodule update --init

	#fix missing pymavlink
	cd modules/mavlink
	sudo git clone --recurse-submodules  https://github.com/ArduPilot/pymavlink.git
		
	cd "$GIT_DIR"

	sudo git clone https://github.com/MonashUAS/cmavnode.git
	cd cmavnode
	sudo git submodule update --init

	sudo git clone https://github.com/RespawnDespair/wifibroadcast-base.git

	cd "$GIT_DIR"

	sudo git clone https://github.com/RespawnDespair/wifibroadcast-base.git
	cd wifibroadcast-base
	sudo git submodule update --init

	cd "$GIT_DIR"

	sudo git clone https://github.com/RespawnDespair/wifibroadcast-osd-orig.git wifibroadcast-osd
	cd wifibroadcast-osd
	sudo git submodule update --init

	cd "$GIT_DIR"

	sudo git clone https://github.com/RespawnDespair/wifibroadcast-rc-orig.git wifibroadcast-rc
	sudo git clone https://github.com/RespawnDespair/wifibroadcast-status.git
	sudo git clone https://github.com/RespawnDespair/wifibroadcast-scripts.git
	sudo git clone https://github.com/RespawnDespair/wifibroadcast-misc.git
	sudo git clone https://github.com/RespawnDespair/wifibroadcast-hello_video.git

	popd
}

function patch_rpi_image {
	#make a copy of the base image
	IMAGE_FILE="$1"
	INSTALL_SCRIPT="$2"
	cp $DATA_DIR/$BASE_IMAGE".img" $IMAGE_FILE

	#mount the image
	mkdir -p "$MNT_DIR"
	# rootfs
	mountpoint -q "$MNT_DIR" || sudo mount "$IMAGE_FILE" -o loop,offset=$((98304*512)),rw,sizelimit=$((7733248*512)) "$MNT_DIR"

	# give it some time
	sleep 5

	# Resize to full size
	LOOP_DEV="$(findmnt -nr -o source $MNT_DIR)"
	resize2fs -f "$LOOP_DEV"

	# boot
	mountpoint -q "$MNT_DIR/boot" || sudo mount "$IMAGE_FILE" -o loop,offset=$((8192*512)),rw,sizelimit=$((88472*512)) "$MNT_DIR/boot"

	mountpoint -q "$MNT_DIR/dev/" || sudo mount --bind /dev "$MNT_DIR/dev/"
	mountpoint -q "$MNT_DIR/sys/" || sudo mount --bind /sys "$MNT_DIR/sys/"
	mountpoint -q "$MNT_DIR/proc/" || sudo mount --bind /proc "$MNT_DIR/proc/"
	mountpoint -q "$MNT_DIR/dev/pts/" || sudo mount --bind /dev/pts "$MNT_DIR/dev/pts"

	#install new kernel
	install_kernel "$MNT_DIR/boot" "$MNT_DIR"

	#install qemu
	sudo cp /usr/bin/qemu-arm-static "$MNT_DIR/usr/bin"

	#clear the preload file
	sudo cp "$MNT_DIR/etc/ld.so.preload" "$MNT_DIR/root"
	sudo cp /dev/null "$MNT_DIR/etc/ld.so.preload"

	#save the version of this build script inside the raspi image
	#hg summary > "$MNT_DIR/home/pi/rpi_wifibroadcast_image_builder_version.txt"
	#hg diff >> "$MNT_DIR/home/pi/rpi_wifibroadcast_image_builder_version.txt"

	#change the /etc/network/interfaces file so that wpa_suppl does not mess around
	sudo bash -c "echo -e \"auto lo\niface lo inet loopback\nauto eth0\nallow-hotplug eth0\niface eth0 inet manual\niface wlan0 inet manual\niface wlan1 inet manual\niface wlan2 inet manual\" > \"$MNT_DIR/etc/network/interfaces\""

	# Copy the overlay content to the relevant folders on the image
	# Could possibly use -a if all the attributes are correct
	sudo cp -r "overlay/." "$MNT_DIR"

	# Copy the GIT structure
	sudo cp -r "$GIT_DIR/." "$MNT_DIR/home/pi/"

	#run the install script (-> do the real work)
	cp $INSTALL_SCRIPT "$MNT_DIR/home/pi"
	sudo mount --bind /etc/resolv.conf "$MNT_DIR/etc/resolv.conf"
	sudo chroot --userspec=1000:1000 "$MNT_DIR" /bin/bash "/home/pi/$INSTALL_SCRIPT"

	sudo cp "$MNT_DIR/root/ld.so.preload" "$MNT_DIR/etc/ld.so.preload"

	sudo umount -l "$MNT_DIR/sys"
	sudo umount -l "$MNT_DIR/proc"
	sudo umount -l "$MNT_DIR/dev/pts"
	sudo umount -l "$MNT_DIR/dev"

	sudo umount -l "$MNT_DIR/boot"
	sudo umount -l "$MNT_DIR/etc/resolv.conf"
	sudo umount -l "$MNT_DIR"
}

#parameters output file name, input files
function zip_image {
	zip $1 $2
}

mkdir -p "$DATA_DIR"

#prepare the kernel
create_git_structure
download_kernel_and_tools
patch_kernel
patch_kernel7
compile_kernel
compile_kernel7

#prepare the images
download_image

IMAGE_NAME="$BASE_IMAGE""_`date +%F`"
IMAGE_FILE="$DATA_DIR/$IMAGE_NAME"".img"
INSTALL_SCRIPT="install_script.sh"

patch_rpi_image "$IMAGE_FILE" "$INSTALL_SCRIPT"
zip_image "$DATA_DIR/$IMAGE_NAME"".zip" "$IMAGE_FILE"

clear
echo "Image created succesfully"
echo "IMAGE PATH: $IMAGE_FILE"
echo "ZIP FILE: $DATA_DIR/$IMAGE_NAME"".zip"

