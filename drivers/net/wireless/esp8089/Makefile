ccflags-y += -DDEBUG -DSIP_DEBUG -DFAST_TX_STATUS
ccflags-y += -DKERNEL_IV_WAR -DRX_SENDUP_SYNC -DDEBUG_FS
ccflags-y += -DSIF_DSR_WAR -DHAS_INIT_DATA -DHAS_FW
ccflags-y += -DESP_USE_SDIO

# This in-tree integration targets the SDIO-connected ESP8089 used on RK3128.
# Keep the SPI transport out of the module unless a dedicated Kconfig option
# is added for it later.
esp8089-y := \
	esp_ctrl.o \
	esp_debug.o \
	esp_ext.o \
	esp_file.o \
	esp_io.o \
	esp_mac80211.o \
	esp_main.o \
	esp_pm.o \
	esp_sip.o \
	esp_utils.o \
	sdio_sif_esp.o \
	testmode.o

obj-$(CONFIG_ESP8089) += esp8089.o
