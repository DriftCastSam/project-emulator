# Buildroot wrapper for the Orbit console image.
#
#   make defconfig   configure Buildroot in output/
#   make image       build the SD card image
#   make menuconfig  tweak the configuration
#
# The bitstream must exist before `make image`; see post-build.sh.

BR_VERSION ?= 2026.02.3
BR_TARBALL  = buildroot-$(BR_VERSION).tar.xz
BR_URL      = https://buildroot.org/downloads/$(BR_TARBALL)
BR_DIR      = buildroot
OUT         = $(CURDIR)/output

.PHONY: all defconfig image menuconfig clean distclean

all: image

$(BR_DIR)/Makefile:
	@echo "fetching Buildroot $(BR_VERSION)"
	@curl -fsSL -o $(BR_TARBALL) $(BR_URL)
	@tar xf $(BR_TARBALL)
	@mv buildroot-$(BR_VERSION) $(BR_DIR)

defconfig: $(BR_DIR)/Makefile
	$(MAKE) -C $(BR_DIR) O=$(OUT) \
		BR2_EXTERNAL=$(CURDIR)/external orbit_pynq_z2_defconfig

image: defconfig
	$(MAKE) -C $(BR_DIR) O=$(OUT)

menuconfig: defconfig
	$(MAKE) -C $(BR_DIR) O=$(OUT) menuconfig

clean:
	-$(MAKE) -C $(BR_DIR) O=$(OUT) clean

distclean:
	rm -rf $(OUT) $(BR_DIR) $(BR_TARBALL)
