export RELEASE_NAME ?= $(shell date +%F)

# preset(device, flavour, memory, bootloader)
define preset
rootfs-$1-$2-$(RELEASE_NAME).tar.gz:
	./make_rootfs.sh $$(subst .tar.gz,,$$@) $$@ $1 $2

archlinux-$1-$2-$(RELEASE_NAME).img: rootfs-$1-$2-$(RELEASE_NAME).tar.gz
	./make_empty_image.sh $$@ $3
	./make_image.sh $$@ $$< $4

.PHONY: archlinux-$1-$2
archlinux-$1-$2: archlinux-$1-$2-$(RELEASE_NAME).img
endef

default: archlinux-pinephone-lambda

DEVICES := pinetab pinephone
$(foreach device,$(DEVICES),$(eval $(call preset,$(device),barebone,2048M,u-boot-sunxi-with-spl-$(device)-552.bin)))
$(foreach device,$(DEVICES),$(eval $(call preset,$(device),phosh,4096M,u-boot-sunxi-with-spl-$(device)-552.bin)))
$(foreach device,$(DEVICES),$(eval $(call preset,$(device),lambda,4096M,u-boot-sunxi-with-spl-$(device)-552.bin)))
