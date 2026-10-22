################################################################################
#
# orbit-rom-nova
#
################################################################################

ORBIT_ROM_NOVA_VERSION = 1.0
ORBIT_ROM_NOVA_SITE = $(BR2_EXTERNAL_ORBIT_PATH)/../../third_party/NovaTheSquirrel
ORBIT_ROM_NOVA_SITE_METHOD = local
ORBIT_ROM_NOVA_DEPENDENCIES = host-cc65 host-python3
ORBIT_ROM_NOVA_LICENSE = GPL-3.0+ (code), CC-BY-NC-SA-4.0 (assets)
ORBIT_ROM_NOVA_LICENSE_FILES = LICENSE.txt

define ORBIT_ROM_NOVA_BUILD_CMDS
	cd $(@D) && $(HOST_DIR)/bin/python3 NtS1LevelConvert.py levels
	cd $(@D) && CC65_HOME=$(HOST_DIR)/share/cc65 \
		$(HOST_DIR)/bin/ca65 src/nova.s -o src/nova.o
	cd $(@D) && CC65_HOME=$(HOST_DIR)/share/cc65 \
		$(HOST_DIR)/bin/ld65 -C src/nova.x src/nova.o -o nova.nes
endef

define ORBIT_ROM_NOVA_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/nova.nes $(TARGET_DIR)/roms/nova.nes
endef

$(eval $(generic-package))
