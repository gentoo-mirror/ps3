EAPI=8
DESCRIPTION="Contains script that initializes RSX GPU on /dev/ps3gpu_*"
HOMEPAGE="https://github.com/damiandudycz/ps3"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="ppc64"
IUSE="systemd"
S="${WORKDIR}"

src_install() {
    einfo "Adding init script..."
    if use systemd; then
        insinto /usr/lib/systemd/system
        doins "${FILESDIR}/ps3gpu-${PVR}".service
    else
        newinitd "${FILESDIR}"/"${PN}-${PVR}" "${PN}"
    fi
}

pkg_postinst() {
    if use systemd; then
        elog "Enabling ps3gpu.service..."
        systemd_enable ps3gpu.service
    else
        elog "To enable ps3gpu at default, run:"
        elog "  rc-update add ps3gpu default"
    fi
}

pkg_postrm() {
    if use systemd; then
        elog "Disabling ps3gpu.service..."
        systemd_disable ps3gpu.service
    else
        elog "To disable ps3gpu from default, run:"
        elog "  rc-update delete ps3gpu default"
    fi
}
