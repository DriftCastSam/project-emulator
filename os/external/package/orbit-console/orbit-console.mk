################################################################################
#
# orbit-console
#
################################################################################

ORBIT_CONSOLE_VERSION = 1.0
ORBIT_CONSOLE_SITE = $(BR2_EXTERNAL_ORBIT_PATH)/../../sw
ORBIT_CONSOLE_SITE_METHOD = local
ORBIT_CONSOLE_LICENSE = MIT
ORBIT_CONSOLE_DEPENDENCIES =

define ORBIT_CONSOLE_BUILD_CMDS
	$(MAKE) -C $(@D)/console \
		CC="$(TARGET_CC)" CFLAGS="$(TARGET_CFLAGS)" \
		CPPFLAGS="$(TARGET_CPPFLAGS)"
	if [ -d $(@D)/nes ]; then \
		$(MAKE) -C $(@D)/nes \
			CC="$(TARGET_CC)" CFLAGS="$(TARGET_CFLAGS)" \
			CXX="$(TARGET_CXX)" CXXFLAGS="$(TARGET_CXXFLAGS)"; \
	fi
endef

define ORBIT_CONSOLE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/console/fbdemo $(TARGET_DIR)/usr/bin/fbdemo
	if [ -x $(@D)/nes/build/orbit-nes ]; then \
		$(INSTALL) -D -m 0755 $(@D)/nes/build/orbit-nes \
			$(TARGET_DIR)/usr/bin/orbit-nes; \
	fi
endef

$(eval $(generic-package))
