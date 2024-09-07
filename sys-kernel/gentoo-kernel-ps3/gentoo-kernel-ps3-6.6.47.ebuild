# Copyright 2020-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

KERNEL_IUSE_GENERIC_UKI=1
KERNEL_IUSE_MODULES_SIGN=1

inherit kernel-build toolchain-funcs

MY_P=linux-${PV%.*}
GENPATCHES_P=genpatches-${PV%.*}-$(( ${PV##*.} + 7 ))
# https://koji.fedoraproject.org/koji/packageinfo?packageID=8
# forked to https://github.com/projg2/fedora-kernel-config-for-gentoo
CONFIG_VER=6.6.12-gentoo
GENTOO_CONFIG_VER=g13

DESCRIPTION="Linux kernel built with Gentoo patches and PS3 patches"
HOMEPAGE="
	https://wiki.gentoo.org/wiki/Project:Distribution_Kernel
	https://www.kernel.org/
"
SRC_URI+="
	https://cdn.kernel.org/pub/linux/kernel/v$(ver_cut 1).x/${MY_P}.tar.xz
	https://dev.gentoo.org/~mpagano/dist/genpatches/${GENPATCHES_P}.base.tar.xz
	https://dev.gentoo.org/~mpagano/dist/genpatches/${GENPATCHES_P}.extras.tar.xz
	https://github.com/projg2/gentoo-kernel-config/archive/${GENTOO_CONFIG_VER}.tar.gz
		-> gentoo-kernel-config-${GENTOO_CONFIG_VER}.tar.gz
	https://raw.githubusercontent.com/damiandudycz/ps3-gentoo-overlay.distfiles/main/sys-kernel/gentoo-kernel-ps3/gentoo-kernel-ps3-${PVR}.tar.xz
"
S=${WORKDIR}/${MY_P}

KEYWORDS="amd64 ~arm arm64 ~hppa ~loong ~ppc ppc64 ~riscv ~sparc x86"
IUSE="debug hardened X"
REQUIRED_USE=""
PATCHES_USE="${IUSE}"

RDEPEND="
	!sys-kernel/gentoo-kernel-bin:${SLOT}
"
BDEPEND="
	debug? ( dev-util/pahole )
"
PDEPEND=""

QA_FLAGS_IGNORED="
	usr/src/linux-.*/scripts/gcc-plugins/.*.so
	usr/src/linux-.*/vmlinux
	usr/src/linux-.*/arch/powerpc/kernel/vdso.*/vdso.*.so.dbg
"

src_prepare() {
	local PATCHES=(
		# meh, genpatches have no directory
		"${WORKDIR}"/*.patch
	)

	# Add PS3 patches matching USE flags
	for patch_file in "${WORKDIR}/ps3_patches/"*.patch; do
		patch_name=$(basename "${patch_file}")
		if [[ ! $patch_name =~ \[([^]]+)\] ]]; then
			PATCHES_PS3+=( "${patch_file}" )
		else
			flags=$(grep -o '\[[^]]*\]' <<< "$patch_name")
			add=false
			while IFS= read -r flag; do
				flag=${flag:1:-1}
				use ${flag} && add=true
			done <<< "$flags"
			if [[ $add = true ]]; then
				PATCHES_PS3+=( "${patch_file}" )
			fi
		fi
	done
	PATCHES+=(${PATCHES_PS3[@]})
	# Sort all patches by name
	sorted_patches=($(for patch in "${PATCHES[@]}"; do echo "$patch"; done | sort))
	PATCHES=("${sorted_patches[@]}")

	default

	cp "${WORKDIR}/ps3_gentoo_defconfig" .config || die

	local myversion="-gentoo-ps3-dist"
	use hardened && myversion+="-hardened"
	echo "CONFIG_LOCALVERSION=\"${myversion}\"" > "${T}"/version.config || die
	local dist_conf_path="${WORKDIR}/gentoo-kernel-config-${GENTOO_CONFIG_VER}"

	local merge_configs=(
		"${T}"/version.config
	)
	use debug || merge_configs+=(
		"${dist_conf_path}"/no-debug.config
	)
	if use hardened; then
		merge_configs+=( "${dist_conf_path}"/hardened-base.config )

		tc-is-gcc && merge_configs+=( "${dist_conf_path}"/hardened-gcc-plugins.config )

		if [[ -f "${dist_conf_path}/hardened-${ARCH}.config" ]]; then
			merge_configs+=( "${dist_conf_path}/hardened-${ARCH}.config" )
		fi
	fi

	merge_configs+=( "${dist_conf_path}/big-endian.config" )

	use secureboot && merge_configs+=( "${dist_conf_path}/secureboot.config" )

	kernel-build_merge_configs "${merge_configs[@]}"
}

pkg_postinst() {
	kernel-build_pkg_postinst
	# Update KBOOT entry:

	# Find root and boot partition
	root_partition=$(awk '!/^[[:space:]]*#/ && $2 == "/" {print $1}' /etc/fstab)
	boot_partition=$(awk '!/^[[:space:]]*#/ && $2 == "/boot" {print $1}' /etc/fstab)

	if [ ! -z "$root_partition" ]; then
		einfo "Root partition detected: $root_partition."
		kboot_path="/etc/kboot.conf"
	fi
	if [ ! -z "$boot_partition" ]; then
		einfo "Boot partition detected: $boot_partition."
		kboot_path="/boot/kboot.conf"
	fi
	if [ -z "$root_partition" ]; then
		ewarn "Skipping kboot configuration, because the root partition was not detected."
		ewarn "Please configure it manually."
	fi
	# If there is no separate /boot partition, the boot entry needs /boot prefix/
	if [ -z "$boot_partition" ]; then
		vmlinux_path_prefix="/boot"
	fi
	kboot_entry="Gentoo-Kernel-${PV}='${vmlinux_path_prefix}/vmlinux-${PV}-gentoo-ps3-dist initrd=${vmlinux_path_prefix}/initramfs-${PV}-gentoo-ps3-dist.img root=${root_partition} video=ps3fb:mode:133'"
	if [ -f "${kboot_path}" ]; then
		grep -qxF "${kboot_entry}" "${kboot_path}" 2>/dev/null || sed -i "1i ${kboot_entry}" "${kboot_path}"
	else
		echo "${kboot_entry}" >> "${kboot_path}"
	fi
	elog "KBOOT entry added to ${kboot_path}"
}
