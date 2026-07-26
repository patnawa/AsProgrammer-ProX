#pragma once 

/*
	buzzpirathlp
	by Dreg @therealdreg https://github.com/therealdreg/ http://buzzpirat.com/
	-
	WARNING: ugly, buggy and crap code
	The program's design is quite messy, and I've only created it for my own needs
	-
	MIT LICENSE
 */

#include <windows.h>

// http://dangerousprototypes.com/docs/Bitbang

#define BHL_I2C_WRITE_THEN_READ        0x08
#define BHL_PERIPHERAL_DISABLE_ALL     0x40
#define BHL_PERIPHERAL_CS              0x41
#define BHL_PERIPHERAL_AUX             0x42
#define BHL_PERIPHERAL_PULLUPS         0x44
#define BHL_PERIPHERAL_PWR             0x48
#define BHL_I2C_SEND_START             0x02
#define BHL_I2C_SEND_STOP              0x03 
#define BHL_I2C_READ_BYTE              0x04
#define BHL_I2C_SEND_ACK               0x06
#define BHL_I2C_SEND_NACK              0x07
#define BHL_I2C_BULK_WRITE             0x10
#define BHL_I2C_400KHZ                 0x63
#define BHL_I2C_100KHZ                 0x62
#define BHL_I2C_50KHZ                  0x61
#define BHL_I2C_5KHZ                   0x60

#define BHL_SPI_CS_ACTIVE_HIGH         0x03
#define BHL_SPI_CS_ACTIVE_LOW          0x02 // default
#define BHL_SPI_WRITE_THEN_READ        0x04
#define BHL_SPI_BULK_TRANSFER          0x10
#define BHL_SPI_8MHZ                   0x67
#define BHL_SPI_4MHZ                   0x66
#define BHL_SPI_2P6MHZ                 0x65
#define BHL_SPI_2MHZ                   0x64
#define BHL_SPI_1MHZ                   0x63
#define BHL_SPI_250KHZ                 0x62
#define BHL_SPI_125KHZ                 0x61
#define BHL_SPI_30KHZ                  0x60

#define BHL_SPI_CONF_DEFAULTS          0x80 // SMPHASE_MIDLE, CKE_IDLE_TO_ACT, CKP_IDLE_LOW, OUT_HIZ
#define BHL_SPI_CONF_SMPHASE_END       0x81 // 0: middle (Input sample phase)
#define BHL_SPI_CONF_CKE_ACT_TO_IDLE   0x82 // 0: Idle to active (Output Clock edge)
#define BHL_SPI_CONF_CKP_IDLE_HIGH     0x84 // 0: Idle low (Clock Polarity)
#define BHL_SPI_CONF_OUT_3V3           0x88 // 0: HIZ

#define BHL_SPI_WRITE_THEN_READ        0x04
#define BHL_SPI_WRITE_THEN_READ_NO_CS  0x05
#define BHL_ENTER_RAW_BITBANG          0x00
#define BHL_ENTER_BIN_I2C              0x02
#define BHL_ENTER_BIN_SPI              0x01
#define BHL_HARD_RESET                 0x0F


#ifdef BUZZPIRATHLP_EXPORTS
#define BUZZPIRATHLP_API __declspec(dllexport)
#else
#define BUZZPIRATHLP_API __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif




BUZZPIRATHLP_API BOOL __stdcall bhl_com_create(const char* com_name);
BUZZPIRATHLP_API void __stdcall bhl_com_close(void);
BUZZPIRATHLP_API void __stdcall bhl_hard_reset(void);
BUZZPIRATHLP_API BOOL __stdcall bhl_set_peripherals(unsigned int peripherals_mask);
BUZZPIRATHLP_API BOOL __stdcall bhl_enter_raw_bitbang(void);
BUZZPIRATHLP_API BOOL __stdcall bhl_enter_bin_i2c(void);
BUZZPIRATHLP_API BOOL __stdcall bhl_enter_bin_spi(void);
BUZZPIRATHLP_API BOOL __stdcall bhl_i2c_speed(unsigned int speed);
BUZZPIRATHLP_API BOOL __stdcall bhl_i2c_eepr_set_2byteaddr(unsigned int chip_addr, unsigned int mem_addr);
BUZZPIRATHLP_API BOOL __stdcall bhl_i2c_eepr_start_bulk(unsigned int chip_addr);
BUZZPIRATHLP_API BOOL __stdcall bhl_i2c_eepr_bulk_read_byte(unsigned char* recv_buff, unsigned int ack_or_nack);
BUZZPIRATHLP_API unsigned int __stdcall bhl_i2c_eepr_stop_bulk(void);
BUZZPIRATHLP_API BOOL __stdcall bhl_i2c_eepr_write_byte_2byteaddr(unsigned int chip_addr, unsigned int mem_addr, unsigned char byte_val, unsigned char* recv_buff);
BUZZPIRATHLP_API unsigned int __stdcall bhl_i2c_scan(unsigned char* detected_array);

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_clear_log(void);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_reset_once(unsigned int setf);

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_init(unsigned int dbglvl, const char* com_name, unsigned int power, unsigned int pullups, unsigned int khz, unsigned int just_i2c_scanner);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_close(void);

BUZZPIRATHLP_API unsigned char* __stdcall bhl_asprog_i2c_get_memaux(void);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_readwrite(unsigned int devaddr, unsigned int size, unsigned char* buffwr, unsigned int size_buffwr);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_start(void);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_stop(void);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_read_byte(void);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_write_byte(unsigned int byte);

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_init(
	unsigned int dbglvl,
	const char* com_name,
	unsigned int spibug,
	unsigned int power,
	unsigned int pullups,
	unsigned int khz,
	unsigned int set_smphase_end,
	unsigned int set_cke_act_to_idle,
	unsigned int set_ckp_idle_high,
	unsigned int set_out_3v3,
	unsigned int set_cs_active_high);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_close(void);
BUZZPIRATHLP_API unsigned char* __stdcall bhl_asprog_spi_get_memaux(void);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_write(unsigned char* bufferw, unsigned int size_wbuffer);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_read(unsigned int size_read);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_readwrite_no_cs(unsigned int size, unsigned char* bufferw, unsigned int size_wbuffer);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_cs_low(void);
BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_cs_high(void);

#ifdef __cplusplus
}
#endif