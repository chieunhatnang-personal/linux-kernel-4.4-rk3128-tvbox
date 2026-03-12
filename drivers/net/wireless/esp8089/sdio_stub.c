/*
 * Copyright (c) 2013 Espressif System.
 *
 *  sdio stub code for RK
 */

#include <linux/delay.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/rfkill-wlan.h>

//#include <mach/iomux.h>

/*
 * Keep the module parameter for compatibility, but Rockchip boards use the
 * existing rfkill power hook instead of a direct GPIO reset from this driver.
 */
static int esp_reset_gpio = 0;
module_param(esp_reset_gpio, int, 0);
MODULE_PARM_DESC(esp_reset_gpio, "ESP8089 CH_PD reset GPIO number");

#define ESP8089_DRV_VERSION "1.9"

int rockchip_wifi_init_module(void)
{	
	return esp_sdio_init();		
}

void rockchip_wifi_exit_module(void)
{
	esp_sdio_exit(); 
		 
}
void sif_platform_rescan_card(unsigned insert)
{
	printk("ESP8089 rescan card: %u\n", insert);
	rockchip_wifi_set_carddetect(insert ? 1 : 0);
}

void sif_platform_reset_target(void)
{
	printk("ESP8089 reset via Rockchip WiFi power hook\n");
	rockchip_wifi_power(0);
	msleep(200);
	rockchip_wifi_power(1);
	msleep(200);
}

void sif_platform_target_poweroff(void)
{
	printk("ESP8089 power off via Rockchip WiFi power hook\n");
	rockchip_wifi_power(0);
	msleep(200);
	rockchip_wifi_set_carddetect(0);
	msleep(50);
}

void sif_platform_target_poweron(void)
{
	printk("ESP8089 power on via Rockchip WiFi power hook\n");
	sif_platform_reset_target();
}

void sif_platform_target_speed(int high_speed)
{
}

void sif_platform_check_r1_ready(struct esp_pub *epub)
{
}


#ifdef ESP_ACK_INTERRUPT
extern void sdmmc_ack_interrupt(struct mmc_host *mmc);

void sif_platform_ack_interrupt(struct esp_pub *epub)
{
        struct esp_sdio_ctrl *sctrl = NULL;
        struct sdio_func *func = NULL;

	if (epub == NULL) {
        	ESSERT(epub != NULL);
		return;
	}
        sctrl = (struct esp_sdio_ctrl *)epub->sif;
        func = sctrl->func;
	if (func == NULL) {
        	ESSERT(func != NULL);
		return;
	}

        sdmmc_ack_interrupt(func->card->host);
}
#endif //ESP_ACK_INTERRUPT
 EXPORT_SYMBOL(rockchip_wifi_init_module);
 EXPORT_SYMBOL(rockchip_wifi_exit_module);

late_initcall(esp_sdio_init);
module_exit(esp_sdio_exit);
