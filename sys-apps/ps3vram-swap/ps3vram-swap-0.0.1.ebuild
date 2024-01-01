EAPI=8
DESCRIPTION="Contains init script that initializes swap on /dev/ps3vram"
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
        doins "${FILESDIR}/ps3vram-${PVR}".service
    else
        newinitd "${FILESDIR}"/"${PN}-${PVR}" "${PN}"
    fi
}

pkg_postinst() {
    if use systemd; then
        elog "Enabling ps3vram.service..."
        systemd_enable ps3vram.service
    else
        elog "To enable ps3vram at boot, run:"
        elog "  rc-update add ps3vram boot"
    fi
}

pkg_postrm() {
    if use systemd; then
        elog "Disabling ps3vram.service..."
        systemd_disable ps3vram.service
    else
        elog "To disable ps3vram from boot, run:"
        elog "  rc-update delete ps3vram boot"
    fi
}
