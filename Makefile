include settings.mk

.PHONY: all toolchain system kernel image clean

help:
	@$(SCRIPTS_DIR)/help.sh

toolchain:
	$(SCRIPTS_DIR)/toolchain.sh

system:
	$(SCRIPTS_DIR)/system.sh

download:
	@wget -c -i wget-list -P $(SOURCES_DIR)

run:
	qemu-system-x86_64 -kernel $(IMAGES_DIR)/bzImage -drive file=$(IMAGES_DIR)/rootfs.ext2,format=raw -append "root=/dev/sda"
