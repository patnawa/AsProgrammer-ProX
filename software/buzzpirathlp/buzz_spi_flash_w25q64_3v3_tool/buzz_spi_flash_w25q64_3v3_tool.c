/*
	buzz_spi_flash_sst25vf080b_tool flasher+dumper for buzzpirat & bus pirate
	by Dreg @therealdreg https://github.com/therealdreg/ http://buzzpirat.com/
	-
	WARNING: ugly, buggy and crap code
	The program's design is quite messy, and I've only created it for my own needs
	-
	MIT LICENSE
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "..\buzzpirathlp\buzzpirathlp.h"

int _main(int argc, char* argv[])
{
	unsigned char* data_recv = NULL;

	bhl_asprog_spi_init("com8", 0, 1, 1, BHL_SPI_125KHZ, 0, 0, 0, 0, 0);
	

	/*
	bhl_asprog_spi_cs_low();
	bhl_asprog_spi_readwrite_no_cs(4, "\x9f", 1);
	bhl_asprog_spi_cs_high();
	data_recv = bhl_asprog_spi_get_memaux();
	*/

	/*
	bhl_asprog_spi_cs_low();
	bhl_asprog_spi_readwrite_no_cs(4, "\x04\x00\x01\x00\x03\x9f", 6);
	bhl_asprog_spi_cs_high();
	data_recv = bhl_asprog_spi_get_memaux();
	*/

	data_recv = NULL;

	bhl_asprog_spi_cs_low();
	bhl_asprog_spi_readwrite_no_cs(0, "\x9f", 1);
	bhl_asprog_spi_readwrite_no_cs(4, NULL, 0);
	bhl_asprog_spi_cs_high();
	data_recv = bhl_asprog_spi_get_memaux();
	data_recv = NULL;

	return 0;
}

int main(int argc, char* argv[])
{
	int retf = _main(argc, argv);

	puts("\nPRESS ENTER TO EXIT!");
	getchar();

	return retf;
}