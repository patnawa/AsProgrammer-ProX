/* 
	buzz_i2c_eeprom_2byteaddr_tool (AT24C256...) flasher+dumper for buzzpirat & bus pirate
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

void buzz_i2c_eeprom_2byteaddr_tool(BOOL read_op, unsigned int datalen, unsigned int memaddr, unsigned int chipaddr, FILE* file, const char* file_name)
{
	unsigned int cnt = 0;
	unsigned char receive_buf[10] = { 0 };
	unsigned int failcount = 0;
	unsigned char curcode = 0;
	unsigned char detected[0xFF] = { 0 };
	unsigned int i = 0;

	printf("If this program freezes (~2 mins without output): close this program, reconnect USB port and try again\n");
	printf("this process can be slow, please, wait and be patient.... never use USB HUB and/or VM!\n");
	Sleep(500);
	bhl_enter_raw_bitbang();
	printf("Entering i2c mode\n");
	bhl_enter_bin_i2c();
	printf("Setting I2C speed 50khz (I dont trust in your crap-cables)\n");
	bhl_i2c_speed(BHL_I2C_50KHZ);
	printf("enabling PULL-UPS and POWER...\n");
	bhl_set_peripherals(BHL_PERIPHERAL_PULLUPS | BHL_PERIPHERAL_PWR);
	Sleep(200);
	cnt = bhl_i2c_scan(detected);
	for (i = 0; i < cnt; i++)
	{
		printf("addr found: 0x%X(%d) -> 0x%X(%d) %s\n", detected[i] >> 1, detected[i] >> 1, detected[i], detected[i], (detected[i] & 0x01) ? "R" : "W");
	}
	bhl_set_peripherals(BHL_PERIPHERAL_DISABLE_ALL);
	Sleep(1500);
	bhl_set_peripherals(BHL_PERIPHERAL_PULLUPS | BHL_PERIPHERAL_PWR);
	Sleep(200);

	if (read_op)
	{
		bhl_i2c_eepr_set_2byteaddr(chipaddr, memaddr);
		bhl_i2c_eepr_start_bulk(chipaddr);
		for (cnt = 0; datalen; datalen--, cnt++)
		{
			if (cnt % 16 == 0)
			{
				printf("\n0x%08X: ", memaddr);
				memaddr += 16;
			}
			bhl_i2c_eepr_bulk_read_byte(receive_buf, BHL_I2C_SEND_ACK);
			printf("%02X(%c) ", receive_buf[0], isalnum(receive_buf[0]) ? receive_buf[0] : ' ');
			fwrite(receive_buf, 1, 1, file);
		}
		printf("\n\n0x%X(%d) bytes saved to %s\n", cnt, cnt, file_name);
		fflush(file);
		bhl_i2c_eepr_stop_bulk();
	}
	else
	{
		failcount = 0;
		cnt = 0;
		while (fread(&curcode, 1, 1, file))
		{
			if (cnt % 16 == 0)
			{
				printf("\n0x%08X: ", memaddr);
			}
			do
			{
				failcount++;
				bhl_i2c_eepr_write_byte_2byteaddr(chipaddr, memaddr, curcode, receive_buf);
				Sleep(5);
			} while (receive_buf[2] || receive_buf[3] || receive_buf[4] || receive_buf[5]);
			printf("%02X(%c) ", curcode, isalnum(curcode) ? curcode : ' ');
			cnt++;
			failcount--;
			memaddr++;
		}
		printf("\n\n0x%X(%d) bytes written from %s to eeprom with %d retries\n", cnt, cnt, file_name, failcount);
	}

	bhl_hard_reset();
}

int _main(int argc, char* argv[])
{
	FILE* file = NULL;
	unsigned int memaddr = 0;
	unsigned int datalen = 0;
	unsigned char chipaddr = 0;
	char* format_char = NULL;
	unsigned int i = 0;
	unsigned int aux = 0;

	puts("\nbuzz_i2c_eeprom_2byteaddr_tool (AT24C256...) flasher+dumper for buzzpirat & bus pirate\n"
		"by Dreg @therealdreg https://github.com/therealdreg/ http://buzzpirat.com/\n"
		"-\n"
		"WARNING : ugly, buggy and crap code\n"
		"The program's design is quite messy, and I've only created it for my own needs\n"
		"-\n"
		"MIT LICENSE\n"
		"-\n"
		"Syntax:\n"
		"	buzz_i2c_eeprom_2byteaddr_tool.exe [com?] [chip addr] [R/W] [file] (len) (mem addr)\n"
		"\n"
		"NOTE: len is ignored when W\n"
		"\n"
		"Example retrieving 500 bytes from 0x69 address (chip addr: 0xA0):\n"
		"	buzz_i2c_eeprom_2byteaddr_tool.exe com8 0xA0 R dump.bin 500 0x69\n");

	printf("cmd line:\n");
	for (i = 0; i < (unsigned int) argc; i++)
	{
		printf("%s ", argv[i]);
	}
	puts("\n");

	if (argc < 4 || argc > 7) 
	{
		puts("bad syntax!");
		return 1;
	}

	format_char = "%d";
	if (strstr(argv[2], "0x") || strstr(argv[2], "0X"))
	{
		format_char = "%x";
	}
	if (!sscanf(argv[2], format_char, &aux))
	{
		printf("Address is invalid\n");
		return 2;
	}
	chipaddr = aux;
	printf("chip addr: 0x%X(%d)\n", chipaddr, chipaddr);

	if (argc >= 6) 
	{
		format_char = "%d";
		if (strstr(argv[5], "0x") || strstr(argv[5], "0X"))
		{
			format_char = "%x";
		}
		if (!sscanf(argv[5], format_char, &datalen)) 
		{
			printf("Data length invalid\n");
			return 3;
		}
	}

	if (argc == 7) 
	{
		format_char = "%d";
		if (strstr(argv[6], "0x") || strstr(argv[6], "0X"))
		{
			format_char = "%x";
		}
		if (!sscanf(argv[6], format_char, &memaddr)) 
		{
			printf("Memory address invalid\n");
			return 3;
		}
		printf("memory addr: 0x%X(%d)\n", memaddr, memaddr);
	}

	if (argv[3][0] != 'R' && argv[3][0] != 'W') 
	{
		printf("Must specify read or write mode\n");
		return 4;
	}

	if (argv[3][0] == 'R' && !datalen) 
	{
		printf("Must specify read length\n");
		return 4;
	}

	printf("file: %s\n", argv[4]);
	if (argv[3][0] == 'R')
	{
		file = fopen(argv[4], "wb");
	}
	else
	{
		file = fopen(argv[4], "rb");
	}
	if (!file) 
	{
		printf("Error opening file: %s\n", argv[4]);
		return 2;
	}

	if (argv[3][0] == 'R')
	{
		puts("READ MODE! (DUMPER)");
		printf("Reading 0x%X(%d) bytes from eeprom (starting from 0x%X(%d)) to %s\n", datalen, datalen, memaddr, memaddr, argv[4]);
	}
	else
	{
		puts("WRITE MODE! (FLASHER)");
		fseek(file, 0L, SEEK_END);
		printf("Writting 0x%X(%d) bytes from %s to eeprom (starting from 0x%X(%d))\n", ftell(file), ftell(file), argv[4], memaddr, memaddr);
		fseek(file, 0L, SEEK_SET);
	}
	
	printf("Connecting to %s\n", argv[1]);
	if (bhl_com_create(argv[1]))
	{
		buzz_i2c_eeprom_2byteaddr_tool(argv[3][0] == 'R' ? TRUE : FALSE, datalen, memaddr, chipaddr, file, argv[4]);
		bhl_com_close();
	}
	
	fclose(file);

	return 0;
}

int main(int argc, char** argv) {
	int ret = _main(argc, argv);
	puts("\n\npress enter to exit!\n");
	getchar();
	return ret;
}