#! /bin/bash

#
# Script for building Android arm64 Kernel
#
# Copyright (c) 2021 tzuyu 
# 
#

# Set environment for directory
KERNEL_DIR=$PWD
IMG_DIR="$KERNEL_DIR"/out/arch/arm64/boot

# Get defconfig file
DEFCONFIG=vendor/ginkgo-perf_defconfig

# Set environment for etc.
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_VERSION="1"
export KBUILD_BUILD_USER="FiqriArdyansyah"
export KBUILD_BUILD_HOST="DroneCI"

# Set environment for telegram
export CHATID="-1001526743824"
export token="5212530113:AAGD6Aa0eJYNXf4oq8zYG3NtCmQlBMvY3AU"
export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"

#
# Set if do you use GCC or clang compiler
# Default is clang compiler
#
COMPILER=clang

# Get distro name
DISTRO=$(cat /etc/issue)

# Get all cores of CPU
PROCS=$(nproc --all)
export PROCS

# Set Date and time
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")

# Get branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)
export BRANCH

# Check kernel version
KERVER=$(make kernelversion)

# Get last commit
COMMIT_HEAD=$(git log --oneline -1)

# Set function for telegram
tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
}

tg_post_build() {
	# Post MD5 Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	# Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3 | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"  
}

# Set function for cloning repository
clone() {
	# Clone AnyKernel3
	git clone --depth=1 https://github.com/fiqri19102002/AnyKernel3.git -b ginkgo

	if [[ $COMPILER == "clang" ]]; then
		# Clone Proton clang
		git clone --depth=1 https://github.com/kdrag0n/proton-clang.git clang
		# Set environment for clang
		TC_DIR=$KERNEL_DIR/clang
		# Get path and compiler string
		KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin/:$PATH
	elif [[ $COMPILER == "gcc" ]]; then
		# Clone GCC ARM64 and ARM32
		git clone --depth=1 https://github.com/arter97/arm64-gcc.git gcc64
		git clone --depth=1 https://github.com/arter97/arm32-gcc.git gcc32
		# Set environment for GCC ARM64 and ARM32
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32
		# Get path and compiler string
		KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
		PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH
	fi
	
	export PATH KBUILD_COMPILER_STRING
}

# Set function for naming zip file
set_naming() {
	KERNEL_NAME="STRIX-ginkgo-personal-$DATE"
	export ZIP_NAME="$KERNEL_NAME.zip"
}

# Set function for starting compile
compile() {
	echo -e "Kernel compilation starting"
	tg_post_msg "<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>Redmi Note 8 (ginkgo)</code>%0A<b>Pipeline Host : </b><code>$KBUILD_BUILD_HOST</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0a<b>Branch : </b><code>$BRANCH</code>%0A<b>Last Commit : </b><code>$COMMIT_HEAD</code>%0A<b>Status : </b>#Personal" "$CHATID"
	make O=out "$DEFCONFIG"
	BUILD_START=$(date +"%s")
	if [[ $COMPILER == "clang" ]]; then
		make -j"$PROCS" O=out \
				CROSS_COMPILE=aarch64-linux-gnu- \
				CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
				CC=clang \
				AR=llvm-ar \
				NM=llvm-nm \
				LD=ld.lld \
				OBJDUMP=llvm-objdump \
				STRIP=llvm-strip
	elif [[ $COMPILER == "gcc" ]]; then
		export CROSS_COMPILE_ARM32=$GCC32_DIR/bin/arm-eabi-
		make -j"$PROCS" O=out CROSS_COMPILE=aarch64-elf-
	fi
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))
	if [ -f "$IMG_DIR"/Image.gz-dtb ] 
	then
		echo -e "Kernel successfully compiled"
	elif ! [ -f "$IMG_DIR"/Image.gz-dtb ]
	then
		echo -e "Kernel compilation failed"
		tg_post_msg "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>" "$CHATID"
		exit 1
	fi
}

# Set function for zipping into a flashable zip
gen_zip() {
	# Move kernel and DTBO image to AnyKernel3
	mv "$IMG_DIR"/Image.gz-dtb AnyKernel3/Image.gz-dtb
	mv "$IMG_DIR"/dtbo.img AnyKernel3/dtbo.img
	cd AnyKernel3 || exit

	# Archive to flashable zip
	zip -r9 "$ZIP_NAME" * -x .git README.md

	# Prepare a final zip variable
	ZIP_FINAL="$ZIP_NAME"

	tg_post_build "$ZIP_FINAL" "$CHATID" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
	cd ..
}

clone
compile
set_naming
gen_zip
