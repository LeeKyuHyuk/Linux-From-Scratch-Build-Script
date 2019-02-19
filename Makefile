include settings.mk

.PHONY: all toolchain system image clean

help:
	@$(SCRIPTS_DIR)/help.sh

all:
	@make clean toolchain system image

toolchain:
	@$(SCRIPTS_DIR)/toolchain.sh

system:
	@$(SCRIPTS_DIR)/system.sh

image:
	@$(SCRIPTS_DIR)/image.sh

clean:
	@sudo rm -rf $(OUTPUT_DIR) && sudo -k

download:
	@wget -c -i wget-list -P $(PACKAGES_DIR)
