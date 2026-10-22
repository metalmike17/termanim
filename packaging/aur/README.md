# AUR packaging

`PKGBUILD`, `.SRCINFO` and `termanim.install` for the Arch User Repository. The package installs termanim system-wide:

- `/usr/bin/termanim` and `/usr/bin/termanim-settings`
- the KWin script in `/usr/share/kwin/scripts/termanim`
- a systemd user unit for the hotkey terminal, and the settings launcher

After installing, each user runs `termanim setup` once. A system package cannot enable a KWin script or start a user service for you.

## Updating for a new release

1. Tag a release and upload `termanim-X.Y.Z.tar.gz` (built with `git archive`, without `media/`).
2. Change `pkgver` in `PKGBUILD`, set `pkgrel=1`, and update `sha256sums` (`sha256sum termanim-X.Y.Z.tar.gz`).
3. Regenerate the metadata: `makepkg --printsrcinfo > .SRCINFO`
4. Test the build in a scratch directory with `makepkg -f`.

## Publishing to the AUR

You need an account on aur.archlinux.org with your SSH public key added.

```sh
git clone ssh://aur@aur.archlinux.org/termanim.git aur-termanim
cp PKGBUILD .SRCINFO termanim.install aur-termanim/
cd aur-termanim
git add PKGBUILD .SRCINFO termanim.install
git commit -m "termanim 1.0.1"
git push
```
