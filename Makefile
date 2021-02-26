export RELEASE_NAME ?= $(shell date +%Y%m%d)

rootfs-pinetab-barebone-$(RELEASE_NAME).tar.gz:
	./make_rootfs.sh rootfs-pinetab-barebone-$(RELEASE_NAME) $@ pinetab barebone

rootfs-pinephone-barebone-$(RELEASE_NAME).tar.gz:
	./make_rootfs.sh rootfs-pinephone-barebone-$(RELEASE_NAME) $@ pinephone barebone

rootfs-pinetab-phosh-$(RELEASE_NAME).tar.gz:
	./make_rootfs.sh rootfs-pinetab-phosh-$(RELEASE_NAME) $@ pinetab phosh

rootfs-pinephone-phosh-$(RELEASE_NAME).tar.gz:
	./make_rootfs.sh rootfs-pinephone-phosh-$(RELEASE_NAME) $@ pinephone phosh

archlinux-pinetab-barebone-$(RELEASE_NAME).img: rootfs-pinetab-barebone-$(RELEASE_NAME).tar.gz
	./make_empty_image.sh $@ 2048M
	./make_image.sh $@ $< u-boot-sunxi-with-spl-pinetab-552.bin

archlinux-pinephone-barebone-$(RELEASE_NAME).img: rootfs-pinephone-barebone-$(RELEASE_NAME).tar.gz
	./make_empty_image.sh $@ 2048M
	./make_image.sh $@ $< u-boot-sunxi-with-spl-pinephone-552.bin

archlinux-pinetab-phosh-$(RELEASE_NAME).img: rootfs-pinetab-phosh-$(RELEASE_NAME).tar.gz
	./make_empty_image.sh $@ 4096M
	./make_image.sh $@ $< u-boot-sunxi-with-spl-pinetab-552.bin

archlinux-pinephone-phosh-$(RELEASE_NAME).img: rootfs-pinephone-phosh-$(RELEASE_NAME).tar.gz
	./make_empty_image.sh $@ 4096M
	./make_image.sh $@ $< u-boot-sunxi-with-spl-pinephone-552.bin

.PHONY: archlinux-pinetab-barebone archlinux-pinephone-barebone archlinux-pinetab-phosh archlinux-pinephone-phosh
archlinux-pinetab-barebone: archlinux-pinetab-barebone-$(RELEASE_NAME).img
archlinux-pinephone-barebone: archlinux-pinephone-barebone-$(RELEASE_NAME).img
archlinux-pinetab-phosh: archlinux-pinetab-phosh-$(RELEASE_NAME).img
archlinux-pinephone-phosh: archlinux-pinephone-phosh-$(RELEASE_NAME).img
