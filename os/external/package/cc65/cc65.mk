################################################################################
#
# host-cc65
#
################################################################################

HOST_CC65_VERSION = 2.19
HOST_CC65_SITE = $(call github,cc65,cc65,V$(HOST_CC65_VERSION))
HOST_CC65_LICENSE = Zlib
HOST_CC65_LICENSE_FILES = LICENSE

define HOST_CC65_BUILD_CMDS
	$(MAKE) -C $(@D) -j$(PARALLEL_JOBS) CC="$(HOSTCC)"
endef

define HOST_CC65_INSTALL_CMDS
	$(MAKE) -C $(@D) install PREFIX=$(HOST_DIR)
endef

$(eval $(host-generic-package))
