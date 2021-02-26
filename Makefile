BUILDDIR = build

EXTRANAME ?=
DATE := $(shell date +%F)

ifeq (EXTRANAME,)
RELEASE_NAME ?= $(DATE)
else
RELEASE_NAME ?= $(DATE)-$(EXTRANAME)
endif

# preset(device, flavour, memory, bootloader)
define preset
$(BUILDDIR)/rootfs-$1-$2-$(RELEASE_NAME).tar.gz: | $(BUILDDIR)
	./make_rootfs.sh $$(subst .tar.gz,,$$@) $$@ $1 $2

$(BUILDDIR)/archlinux-$1-$2-$(RELEASE_NAME).img: $(BUILDDIR)/rootfs-$1-$2-$(RELEASE_NAME).tar.gz | $(BUILDDIR)
	./make_empty_image.sh $$@ $3
	./make_image.sh $$@ $$< $4

.PHONY: archlinux-$1-$2
archlinux-$1-$2: $(BUILDDIR)/archlinux-$1-$2-$(RELEASE_NAME).img
endef

default: archlinux-pinephone-lambda

$(BUILDDIR):
	mkdir $@

DEVICES := pinetab pinephone
$(foreach device,$(DEVICES),$(eval $(call preset,$(device),barebone,2048M,u-boot-sunxi-with-spl-$(device)-552.bin)))
$(foreach device,$(DEVICES),$(eval $(call preset,$(device),phosh,4096M,u-boot-sunxi-with-spl-$(device)-552.bin)))
$(foreach device,$(DEVICES),$(eval $(call preset,$(device),lambda,4096M,u-boot-sunxi-with-spl-$(device)-552.bin)))
