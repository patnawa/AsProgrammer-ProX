/*
	buzzpirathlp
	by Dreg @therealdreg https://github.com/therealdreg/ http://buzzpirat.com/
	-
	WARNING: ugly, buggy and crap code
	The program's design is quite messy, and I've only created it for my own needs
	-
	MIT LICENSE
 */

#include <stdio.h>
#include <windows.h>
#include "buzzpirathlp.h"
#include "log_en.h"
#include <share.h>

unsigned int gdbglvl = 0;
unsigned int idblk = 0;

#define TIME_DBG_P (0x69 / 5)

typedef struct
{
	HANDLE handle;
} COMOP_t;

typedef enum
{
	LSTP_NONE = 0,
	LSTP_SPI,
	LSTP_I2C
} last_prot_t;

COMOP_t* volatile com_glb = NULL;
unsigned char* volatile i2c_memaux = NULL;
unsigned char* volatile spi_memaux = NULL;
extern unsigned int volatile end_fast;
unsigned int volatile reset_once = 0;
last_prot_t volatile last_prot = LSTP_NONE;

const char* const as_msg = "keep pressing ESC key to cancel... keep pressing F1 to relaunch this console... ASProgrammer GUI will be unresponsive while BUS PIRATE is operating. BUS PIRATE is slow, please be (very) patient. If bus pirate console freezes(~2 mins without output)/crash : close this program, reconnect USB port and try again.";

unsigned int volatile spibug_enabled = 0;


BOOL CreateCOM(COMOP_t* com, const char* name)
{
	DCB my_dcb = { 0 };
	COMMTIMEOUTS timeouts = { 0 };
	static char wincomname[300] = { 0 };

	memset(wincomname, 0, sizeof(wincomname));

	if (com == NULL || strlen(name) > 100) // craaap
	{
		return FALSE;
	}

	memset(com, 0, sizeof(*com));

	sprintf(wincomname, "\\\\.\\%s", name);

	com->handle = CreateFileA(wincomname, GENERIC_READ | GENERIC_WRITE, 0, 0, OPEN_EXISTING, FILE_FLAG_NO_BUFFERING | FILE_ATTRIBUTE_NORMAL, 0);
	if (com->handle == INVALID_HANDLE_VALUE) {
		fprintf(LOG_FILE, "Error Opening Serial Port: %s\n", wincomname);
		return FALSE;
	}

	my_dcb.DCBlength = sizeof(my_dcb);
	GetCommState(com->handle, &my_dcb);
	my_dcb.BaudRate = CBR_115200;
	my_dcb.ByteSize = 8;
	my_dcb.StopBits = ONESTOPBIT;
	my_dcb.Parity = NOPARITY;

	if (!SetCommState(com->handle, &my_dcb)) {
		fprintf(LOG_FILE, "Error setting up serial port: %s\n", wincomname);
		return FALSE;
	}

	GetCommTimeouts(com->handle, &timeouts);

	timeouts.ReadIntervalTimeout = 20;
	timeouts.ReadTotalTimeoutMultiplier = 15;
	timeouts.ReadTotalTimeoutConstant = 100;
	timeouts.WriteTotalTimeoutMultiplier = 15;
	timeouts.WriteTotalTimeoutConstant = 100;

	SetCommTimeouts(com->handle, &timeouts);

	return TRUE;
}



BOOL CloseCOM(COMOP_t* com)
{
	if (com == NULL)
	{
		return FALSE;
	}

	CloseHandle(com->handle);

	memset(com, 0, sizeof(*com));

	return TRUE;
}

size_t WINAPI ComWriteBuff(COMOP_t* com, unsigned char* buffer, size_t bytes_to_write, unsigned int max_tries)
{
	size_t total_bytes_written = 0;
	size_t cur_bytes_written = 0;

	if (max_tries == 0)
	{
		max_tries = 5;
	}

	do
	{
		cur_bytes_written = 0;
		if (WriteFile(com->handle, buffer + total_bytes_written, bytes_to_write - total_bytes_written, &cur_bytes_written, 0))
		{
			if (cur_bytes_written)
			{
				total_bytes_written += cur_bytes_written;
			}
			else
			{
				Sleep(5);
			}
		}
		max_tries--;
	} while (bytes_to_write > total_bytes_written && max_tries > 0);

	return total_bytes_written;
}

size_t WINAPI ComWriteByte(COMOP_t* com, unsigned char byte_to_write, unsigned int max_tries)
{
	unsigned char aux_byte = 0;

	aux_byte = byte_to_write;

	return ComWriteBuff(com, &aux_byte, 1, max_tries);
}


size_t WINAPI ComReadBuff(COMOP_t* com, unsigned char* buffer, size_t bytes_to_read, unsigned int max_tries)
{
	size_t total_bytes_readed = 0;
	size_t cur_bytes_readed = 0;

	if (max_tries == 0)
	{
		max_tries = 5;
	}

	do
	{
		cur_bytes_readed = 0;
		if (ReadFile(com->handle, buffer + total_bytes_readed, bytes_to_read - total_bytes_readed, &cur_bytes_readed, 0))
		{
			if (cur_bytes_readed)
			{
				total_bytes_readed += cur_bytes_readed;
			}
			else
			{
				Sleep(5);
			}
		}
		max_tries--;
	} while (bytes_to_read > total_bytes_readed && max_tries > 0);

	return total_bytes_readed;
}

size_t WINAPI ComReadByte(COMOP_t* com, unsigned char* byte_readed, unsigned int max_tries)
{
	return ComReadBuff(com, byte_readed, 1, max_tries);
}

void FlushCOMIn(COMOP_t* com)
{
	unsigned char byte_readed;

	while (ComReadByte(com, &byte_readed, 0));
}


BOOL EnterBINMode(COMOP_t* com)
{
	unsigned char recv_byte = 0;
	size_t bytes_received = 0;

	ComWriteByte(com, BHL_HARD_RESET, 0);
	Sleep(100);
	FlushCOMIn(com);
	for (int i = 0; i < 10; i++)
	{
		bytes_received = ComWriteByte(com, 0x0d, 0);
		bytes_received = ComReadByte(com, &recv_byte, 0);
		bytes_received = ComWriteByte(com, 0x0a, 0);
		bytes_received = ComReadByte(com, &recv_byte, 0);
	}

	for (int i = 0; i < 3; i++)
	{
		bytes_received = ComWriteByte(com, '#', 0);
		Sleep(100);
	}
	FlushCOMIn(com);

	while (1)
	{
		if (bytes_received == 0)
		{
			bytes_received = ComWriteByte(com, BHL_ENTER_RAW_BITBANG, 0);
		}
		if (recv_byte != 'B')
		{
			bytes_received = ComReadByte(com, &recv_byte, 0);
		}
		if (recv_byte == 'B')
		{
			bytes_received = ComReadByte(com, &recv_byte, 0);
			if (recv_byte == 'B')
			{
				bytes_received = ComReadByte(com, &recv_byte, 0);
				if (recv_byte == 'I')
				{
					bytes_received = ComReadByte(com, &recv_byte, 0);
					if (recv_byte == 'O')
					{
						bytes_received = ComReadByte(com, &recv_byte, 0);
						if (recv_byte == '1')
						{
							return TRUE;
						}
					}
				}
			}
		}
	}

	return FALSE;
}


BOOL EnterSPIMode(COMOP_t* com)
{
	unsigned char recv_byte = 0;
	size_t bytes_received = 0;

	FlushCOMIn(com);

	while (1)
	{
		if (bytes_received == 0)
		{
			bytes_received = ComWriteByte(com, BHL_ENTER_BIN_SPI, 0);
		}
		if (recv_byte != 'S')
		{
			bytes_received = ComReadByte(com, &recv_byte, 0);
		}
		if (recv_byte == 'S')
		{
			bytes_received = ComReadByte(com, &recv_byte, 0);
			if (recv_byte == 'P')
			{
				bytes_received = ComReadByte(com, &recv_byte, 0);
				if (recv_byte == 'I')
				{
					bytes_received = ComReadByte(com, &recv_byte, 0);
					if (recv_byte == '1')
					{
						return TRUE;
					}
				}
			}
		}
	}

	return FALSE;
}

BOOL EnterI2CMode(COMOP_t* com)
{
	unsigned char recv_byte = 0;
	size_t bytes_received = 0;

	FlushCOMIn(com);

	while (1)
	{
		if (bytes_received == 0)
		{
			bytes_received = ComWriteByte(com, BHL_ENTER_BIN_I2C, 0);
		}
		if (recv_byte != 'I')
		{
			bytes_received = ComReadByte(com, &recv_byte, 0);
		}
		if (recv_byte == 'I')
		{
			bytes_received = ComReadByte(com, &recv_byte, 0);
			if (recv_byte == '2')
			{
				bytes_received = ComReadByte(com, &recv_byte, 0);
				if (recv_byte == 'C')
				{
					bytes_received = ComReadByte(com, &recv_byte, 0);
					if (recv_byte == '1')
					{
						return TRUE;
					}
				}
			}
		}
	}

	return FALSE;
}


void ResetBusPirate(COMOP_t* com)
{
	EnterBINMode(com);
	ComWriteByte(com, BHL_HARD_RESET, 0);
	Sleep(100);
}

BUZZPIRATHLP_API void __stdcall bhl_hard_reset(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	ResetBusPirate(com_glb);
}

BUZZPIRATHLP_API void __stdcall bhl_com_close(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	COMMTIMEOUTS timeouts = { 0 };

	if (com_glb)
	{
		SetCommTimeouts(com_glb->handle, &timeouts);
		CloseCOM(com_glb);
		free(com_glb);
		com_glb = NULL;
	}
}

BUZZPIRATHLP_API BOOL __stdcall bhl_com_create(const char* com_name)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	if (com_glb)
	{
		bhl_com_close();
	}

	com_glb = calloc(1, sizeof(*com_glb));
	if (com_glb)
	{
		if (CreateCOM(com_glb, com_name))
		{
			return TRUE;
		}
		bhl_com_close();
	}

    return FALSE;
}

BUZZPIRATHLP_API BOOL __stdcall bhl_enter_raw_bitbang(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	fprintf(LOG_FILE, "Resetting bus pirate, wait ~1 min (5 mins without response == reconnect USB and try again)...\n");
	ResetBusPirate(com_glb);
	Sleep(500);
	fprintf(LOG_FILE, "Entering bin mode, wait ~1 min  (5 mins without response == reconnect USB and try again)...\n");
	EnterBINMode(com_glb);
	Sleep(500);
	FlushCOMIn(com_glb);

	return TRUE;
}

BUZZPIRATHLP_API BOOL __stdcall bhl_enter_bin_spi(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	EnterSPIMode(com_glb);
	Sleep(500);
	fprintf(LOG_FILE, "Flushing Com In\n");
	FlushCOMIn(com_glb);

	return TRUE;
}

BUZZPIRATHLP_API BOOL __stdcall bhl_enter_bin_i2c(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	EnterI2CMode(com_glb);
	Sleep(500);
	fprintf(LOG_FILE, "Flushing Com In\n");
	FlushCOMIn(com_glb);

	return TRUE;
}

BUZZPIRATHLP_API BOOL __stdcall bhl_i2c_speed(unsigned int speed)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	ComWriteByte(com_glb, BHL_I2C_50KHZ, 0);
	FlushCOMIn(com_glb);

	return TRUE;
}


BUZZPIRATHLP_API BOOL __stdcall bhl_set_peripherals(unsigned int peripherals_mask)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	ComWriteByte(com_glb, peripherals_mask, 0);
	FlushCOMIn(com_glb);

	return TRUE;
}


BUZZPIRATHLP_API BOOL __stdcall bhl_i2c_eepr_set_2byteaddr(unsigned int chip_addr, unsigned int mem_addr)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char buff[] = { BHL_I2C_SEND_START, BHL_I2C_BULK_WRITE | 2, chip_addr & 0xFFFFFFFE, (mem_addr >> 8) & 0x000000FF, mem_addr & 0x000000FF, BHL_I2C_SEND_STOP };

	fprintf(LOG_FILE, "chip addr: 0x%X(%d) setting eppaddr mem_addr_1byte: 0x%X(%d) mem_addr_2byte: 0x%X(%d)\n", buff[2], buff[2], buff[3], buff[3], buff[4], buff[4]);

	ComWriteBuff(com_glb, buff, 6, 0);
	FlushCOMIn(com_glb);

	return TRUE;
}


BUZZPIRATHLP_API BOOL __stdcall bhl_i2c_eepr_start_bulk(unsigned int chip_addr)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char buff[] = { BHL_I2C_SEND_START, BHL_I2C_BULK_WRITE, chip_addr | 1 };

	fprintf(LOG_FILE, "chip addr for bulk: 0x%X(%d)\n", buff[2], buff[2]);

	ComWriteBuff(com_glb, buff, 3, 0);
	FlushCOMIn(com_glb);

	return TRUE;
}

BUZZPIRATHLP_API BOOL __stdcall bhl_i2c_eepr_bulk_read_byte(unsigned char* recv_buff, unsigned int ack_or_nack)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char buff[] = { BHL_I2C_READ_BYTE, ack_or_nack };
	
	recv_buff[0] = 0;
	recv_buff[1] = 0;

	ComWriteBuff(com_glb, buff, 2, 0);
	ComReadBuff(com_glb, recv_buff, 2, 0);

	return TRUE;
}

BUZZPIRATHLP_API unsigned int __stdcall bhl_i2c_eepr_stop_bulk(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char buff[] = { BHL_I2C_READ_BYTE, BHL_I2C_SEND_NACK, BHL_I2C_SEND_STOP };
	unsigned char recv_buff[10] = { 0 };

	ComWriteBuff(com_glb, buff, 3, 0);
	ComReadBuff(com_glb, recv_buff, 4, 0);

	return recv_buff[0];
}


BUZZPIRATHLP_API BOOL __stdcall bhl_i2c_eepr_write_byte_2byteaddr(unsigned int chip_addr, unsigned int mem_addr, unsigned char byte_val, unsigned char* recv_buff)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char buff[] = { BHL_I2C_SEND_START, BHL_I2C_BULK_WRITE | 3, chip_addr & 0xFFFFFFFE, (mem_addr >> 8) & 0x000000FF, mem_addr & 0x000000FF, byte_val, BHL_I2C_SEND_STOP };

	/*
	fprintf(LOG_FILE, "chip addr for eepr_write_byte: 0x%X(%d) mem_addr_1byte: 0x%X(%d) mem_addr_2byte: 0x%X(%d)\n",
		buff[2], buff[2],
		buff[3], buff[3],
		buff[4], buff[4]);
		*/

	ComWriteBuff(com_glb, buff, 7, 0);
	memset(recv_buff, 0, 7);
	ComReadBuff(com_glb, recv_buff, 7, 0);

	return TRUE;
}

BUZZPIRATHLP_API unsigned int __stdcall bhl_i2c_scan(unsigned char* detected_array)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned int i = 0;
	unsigned char buff[] = { BHL_I2C_SEND_START, BHL_I2C_BULK_WRITE, 0, BHL_I2C_SEND_STOP };
	unsigned char recv_buff[5] = { 0 };
	unsigned int founds = 0;

	fprintf(LOG_FILE, "I2C SCANNER\n");

	FlushCOMIn(com_glb);

	for (i = 1; i < 0xFE; i++)
	{
		buff[2] = i;
		ComWriteBuff(com_glb, buff, 4, 0);
		memset(recv_buff, 0xcc, sizeof(recv_buff));
		ComReadBuff(com_glb, recv_buff, 4, 0);
		if (recv_buff[2] == 0)
		{
			detected_array[founds++] = i;
			fprintf(LOG_FILE, "addr found: 0x%X(%d) -> 0x%X(%d) %s\n", i >> 1, i >> 1, i, i, (i & 0x01) ? "R" : "W");
		}
	}

	FlushCOMIn(com_glb);

	return founds;
}

BUZZPIRATHLP_API unsigned char* __stdcall bhl_asprog_spi_get_memaux(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	return spi_memaux;
}

volatile unsigned int last_status = 0x69;


BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_cs_low(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char status = 0;

	fprintf(LOG_FILE, "bhl_asprog_spi_cs_low\n");

	if (last_status == 0)
	{
		fprintf(LOG_FILE, "skipping...\n");
		return 1;
	}

	last_status = 0;

	ComWriteByte(com_glb, BHL_SPI_CS_ACTIVE_LOW, 0);
	ComReadByte(com_glb, &status, 0);

	return 1;
}

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_cs_high(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char status = 0;

	fprintf(LOG_FILE, "bhl_asprog_spi_cs_high\n");

	if (last_status == 1)
	{
		fprintf(LOG_FILE, "skipping...\n");
		return 1;
	}

	last_status = 1;

	ComWriteByte(com_glb, BHL_SPI_CS_ACTIVE_HIGH, 0);
	ComReadByte(com_glb, &status, 0);

	return 1;
}

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_clear_log(void)
{ // crap in the crap wtf MUTEXXXX
	#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	FILE* tmp_aux = NULL;

	fprintf(LOG_FILE, "bhl_asprog_clear_log");

	Sleep(5000);
	system("cmd /c start taskkill /f /t /im tail.exe");
	Sleep(5000);

	if (LOG_FILE != stdout)
	{
		tmp_aux = LOG_FILE;
		LOG_FILE = stdout;
		Sleep(3000);
		fclose(tmp_aux);
		tmp_aux = NULL;
	}

	tmp_aux = _fsopen("buzzpirathlp.log", "wb", _SH_DENYWR);
	if (tmp_aux != NULL)
	{
		setvbuf(tmp_aux, NULL, _IONBF, 0);
	}

	if (NULL == tmp_aux)
	{
		tmp_aux = stdout;
	}

	LOG_FILE = tmp_aux;

	system("cmd /c start tail -F buzzpirathlp.log");
	
	fprintf(LOG_FILE, "bhl_asprog_clear_log END");

	return 1;
}

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_readwrite_no_cs(unsigned int size, unsigned char* bufferw, unsigned int size_wbuffer)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char high = 0;
	unsigned char low = 0;
	unsigned int i = 0;
	unsigned int j = 0;

	if (end_fast)
	{
		return 0;
	}

	fprintf(LOG_FILE, "\nbhl_asprog_spi_readwrite_no_cs size: 0x%X(%d) - bufferw: 0x%X(%d) - size_wbuffer: 0x%X(%d)\n", 
		size, size, bufferw, bufferw, size_wbuffer, size_wbuffer);

	if (size_wbuffer > 4096)
	{
		MessageBoxA(NULL, "size_wbuffer bigger", "size_wbuffer bigger", MB_OK | MB_TOPMOST | MB_ICONWARNING);
		return 0;
	}

	if (size_wbuffer)
	{
		for (i = 0; i < size_wbuffer; i++)
		{
			fprintf(LOG_FILE, "0x%02X ", bufferw[i]);
		}
		fprintf(LOG_FILE, "-\n\n");
	}

	ComWriteByte(com_glb, BHL_SPI_WRITE_THEN_READ_NO_CS, 0);
	ComWriteByte(com_glb, (size_wbuffer >> 8) & 0x000000FF, 0);
	Sleep(1);
	ComWriteByte(com_glb, size_wbuffer & 0x000000FF, 0);
	ComWriteByte(com_glb, (size >> 8) & 0x000000FF, 0);
	Sleep(1);
	ComWriteByte(com_glb, size & 0x000000FF, 0);
	Sleep(1);
	if (size_wbuffer)
	{
		for (i = 0; i < size_wbuffer; i++)
		{
			ComWriteByte(com_glb, bufferw[i], 0);
		}
	}

	if (!size && !spibug_enabled)
	{
		if (gdbglvl)
			Sleep(1);
		Sleep(1);
		do
		{
			if (end_fast)
			{
				return 0;
			}
			spi_memaux[0] = 0;
			ComReadByte(com_glb, spi_memaux, 0);
			if (spi_memaux[0] != 1)
			{
				fprintf(LOG_FILE, "waiting for bus pirate... if you are looking this msg a lot of time, close asprogrammer and CHECK SPI BUG CHECKBOX...");
			}
		} while (spi_memaux[0] != 1);
	}

	if (size)
	{
		if (gdbglvl)
			Sleep(1);

		Sleep(1);
		do
		{
			if (end_fast)
			{
				return 0;
			}
			spi_memaux[0] = 0;
			ComReadByte(com_glb, spi_memaux, 0);
			if (spi_memaux[0] != 1)
			{
				fprintf(LOG_FILE, "waiting for bus pirate...  if you are looking this msg a lot of time try another USB CABLE....");
			}
		} while (spi_memaux[0] != 1);

		ComReadBuff(com_glb, spi_memaux, size, 0);
		
		if (!gdbglvl || (idblk++ % TIME_DBG_P) == 0)
		{
			fprintf(LOG_FILE, "\n0x%08X  ", 0);
			for (i = 0; i < size; i++)
			{
				fprintf(LOG_FILE, "%02X ", spi_memaux[i]);
				if ((i + 1) % 8 == 0)
				{
					fprintf(LOG_FILE, "  ");
					for (j = i - 7; j < i; j++)
					{
						fprintf(LOG_FILE, "%c", (spi_memaux[j] >= 0x20 && spi_memaux[j] <= 0x7E) ? spi_memaux[j] : '.');
					}
					if (i + 1 != size)
					{
						fprintf(LOG_FILE, "\n0x%08X  ", i);
					}
				}
			}
			j = i - (size % 8);
			for (; j < i; j++)
			{
				fprintf(LOG_FILE, "%c", (spi_memaux[j] >= 0x20 && spi_memaux[j] <= 0x7E) ? spi_memaux[j] : '.');
			}
			fprintf(LOG_FILE, "\n\n");
		}
	}

	// FlushCOMIn(com_glb);

	if (gdbglvl)
		Sleep(1);

	return 1;
}

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_write(unsigned char* bufferw, unsigned int size_wbuffer)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char high = 0;
	unsigned char low = 0;
	unsigned int i = 0;
	
	fprintf(LOG_FILE, "\nbhl_asprog_spi_write bufferw: 0x%X(%d) size_wbuffer: 0x%X(%d)\n", bufferw, bufferw, size_wbuffer, size_wbuffer);

	if (size_wbuffer > 4096)
	{
		MessageBoxA(NULL, "size_wbuffer bigger", "size_wbuffer bigger", MB_OK | MB_TOPMOST | MB_ICONWARNING);
		return 0;
	}

	for (i = 0; i < size_wbuffer; i++)
	{
		fprintf(LOG_FILE, "0x%02X ", bufferw[i]);
	}
	fprintf(LOG_FILE, "-\n\n");


	high = (size_wbuffer >> 8) & 0x000000FF;
	low = size_wbuffer & 0x000000FF;

	ComWriteByte(com_glb, BHL_SPI_WRITE_THEN_READ, 0);
	ComWriteByte(com_glb, high, 0);
	ComWriteByte(com_glb, low, 0);
	ComWriteByte(com_glb, 0, 0);
	ComWriteByte(com_glb, 0, 0);

	ComWriteBuff(com_glb, bufferw, size_wbuffer, 0);

	do
	{
		if (end_fast)
		{
			return 0;
		}
		spi_memaux[0] = 0;
		ComReadByte(com_glb, spi_memaux, 0);
	} while (spi_memaux[0] != 1);

	FlushCOMIn(com_glb);

	return 1;
}

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_reset_once(unsigned int setf)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)

	fprintf(LOG_FILE, "\nreset once: %d\n", setf);

	reset_once = setf;

	return 1;
}


BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_read(unsigned int size_read)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char high = 0;
	unsigned char low = 0;

	fprintf(LOG_FILE, "\nbhl_asprog_spi_read size_read: 0x%X(%d)\n", size_read, size_read);

	if (size_read > 4096)
	{
		MessageBoxA(NULL, "size_read bigger", "size_read bigger", MB_OK | MB_TOPMOST | MB_ICONWARNING);
		return 0;
	}

	high = (size_read >> 8) & 0x000000FF;
	low = size_read & 0x000000FF;

	ComWriteByte(com_glb, BHL_SPI_WRITE_THEN_READ, 0);
	ComWriteByte(com_glb, 0, 0);
	ComWriteByte(com_glb, 0, 0);
	ComWriteByte(com_glb, high, 0);
	ComWriteByte(com_glb, low, 0);

	do
	{
		if (end_fast)
		{
			return 0;
		}
		spi_memaux[0] = 0;
		ComReadByte(com_glb, spi_memaux, 0);
	} while (spi_memaux[0] != 1);

	ComReadBuff(com_glb, spi_memaux, size_read, 0);

	FlushCOMIn(com_glb);

	return 1;
}

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
	unsigned int set_cs_active_high)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned int phs = 0;
	unsigned int speed = 0;
	unsigned config = 0;
	
	//gdbglvl = dbglvl;
	gdbglvl = 0;
	idblk = 0;

	fprintf(LOG_FILE, "\n\n%s\n\ncom_name: %s - spibug: %d - power: %d - pullups: %d - "
		"khz: %d - set_smphase_end: %d - set_cke_act_to_idle: %d - set_ckp_idle_high: %d - set_out_3v3: %d - set_cs_active_high: %d\n", 
		as_msg, com_name, spibug, power, pullups, 
		khz, set_smphase_end, set_cke_act_to_idle, set_ckp_idle_high, set_out_3v3, set_cs_active_high);

	spibug_enabled = spibug;

	if (spibug_enabled)
	{
		fprintf(LOG_FILE, "\nWARNING: spibug_enabled dont works with a fixed firmware!\n");
	}

	end_fast = 0;

	last_status = 0x69;

	if (reset_once && last_prot == LSTP_SPI && NULL != com_glb)
	{
		return 1;
	}

	last_prot = LSTP_SPI;

	phs = BHL_PERIPHERAL_DISABLE_ALL;

	if (pullups)
	{
		phs |= BHL_PERIPHERAL_PULLUPS;
	}

	if (power)
	{
		phs |= BHL_PERIPHERAL_PWR;
	}

	switch (khz)
	{
	case 30:
		speed = BHL_SPI_30KHZ;
		break;

	case 125:
		speed = BHL_SPI_125KHZ;
		break;

	case 250:
		speed = BHL_SPI_250KHZ;
		break;

	case 1:
		speed = BHL_SPI_1MHZ;
		break;

	case 2:
		speed = BHL_SPI_2MHZ;
		break;

	case 26:
		speed = BHL_SPI_2P6MHZ;
		break;

	case 4:
		speed = BHL_SPI_4MHZ;
		break;

	case 8:
		speed = BHL_SPI_8MHZ;
		break;

	default:
		return 0;
		break;
	}

	config = BHL_SPI_CONF_DEFAULTS | BHL_SPI_CONF_CKE_ACT_TO_IDLE;
	if (set_out_3v3 && !pullups)
	{
		config |= BHL_SPI_CONF_OUT_3V3;
	}

	if (!bhl_com_create(com_name))
	{
		return 0;
	}

	if (NULL == spi_memaux)
	{
		spi_memaux = calloc(0x1000, 30000);
		if (NULL == spi_memaux)
		{
			MessageBoxA(NULL, "ERROR SPI MEMAUX ALLOC", "ERROR SPI MEMAUX ALLOC", MB_OK | MB_TOPMOST | MB_ICONWARNING);
			bhl_com_close();
			return 0;
		}
	}

	Sleep(500);
	bhl_enter_raw_bitbang();
	fprintf(LOG_FILE, "Entering SPI mode\n");
	bhl_enter_bin_spi();
	fprintf(LOG_FILE, "enabling PHS (PULL-UPS and POWER)...\n");
	phs |= BHL_PERIPHERAL_CS;
	fprintf(LOG_FILE, "phs: 0x%X\n", phs);
	bhl_set_peripherals(phs);
	fprintf(LOG_FILE, "speed: 0x%X\n", speed);
	ComWriteByte(com_glb, speed, 0);
	fprintf(LOG_FILE, "config: 0x%X\n", config);
	ComWriteByte(com_glb, config, 0);
	fprintf(LOG_FILE, "cs: 0x%X\n", BHL_SPI_CS_ACTIVE_HIGH);
	ComWriteByte(com_glb, BHL_SPI_CS_ACTIVE_HIGH, 0);
	Sleep(200);
	FlushCOMIn(com_glb);

	return 1;
}


BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_spi_close(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	fprintf(LOG_FILE, "bhl_asprog_spi_close\n");

	if (NULL != com_glb)
	{
		bhl_hard_reset();
		bhl_com_close();
		com_glb = NULL;
	}

	return 1;
}

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_init(unsigned int dbglvl, const char* com_name, unsigned int power, unsigned int pullups, unsigned int khz, unsigned int just_i2c_scanner)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned int speed = 0;
	unsigned int phs = 0;
	unsigned i2c_detected = 0;
	unsigned int retf = 0;
	unsigned int i = 0;
	unsigned char* curr = NULL;
	
	gdbglvl = dbglvl;
	gdbglvl = 0;
	idblk = 0;

	fprintf(LOG_FILE, "\n\n%s\n\ncom_name: %s - power: %d - pullups: %d - "
		"khz: %d just_i2c_scanner: %d\n", 
		as_msg, com_name, power, pullups, 
		khz, just_i2c_scanner);

	//__debugbreak();

	end_fast = 0;

	if (reset_once && last_prot == LSTP_I2C && NULL != com_glb && !just_i2c_scanner)
	{
		return 1;
	}

	last_prot = LSTP_I2C;

	phs = BHL_PERIPHERAL_DISABLE_ALL;

	if (pullups)
	{
		phs |= BHL_PERIPHERAL_PULLUPS;
	}

	if (power)
	{
		phs |= BHL_PERIPHERAL_PWR;
	}

	speed = BHL_I2C_50KHZ;

	switch (khz)
	{
	case 5:
		speed = BHL_I2C_5KHZ;
		break;

	case 50:
		speed = BHL_I2C_50KHZ;
		break;

	case 100:
		speed = BHL_I2C_100KHZ;
		break;

	case 400:
		speed = BHL_I2C_400KHZ;
		break;

	default:
		return 0;
		break;
	}

	if (!bhl_com_create(com_name))
	{
		return 0;
	}

	if (NULL == i2c_memaux)
	{
		i2c_memaux = calloc(0x1000, 30000);
		if (NULL == i2c_memaux)
		{
			MessageBoxA(NULL, "ERROR MEMAUX ALLOC", "ERROR MEMAUX ALLOC", MB_OK | MB_TOPMOST | MB_ICONWARNING);
			bhl_com_close();
			return 0;
		}
	}

	Sleep(500);
	bhl_enter_raw_bitbang();
	fprintf(LOG_FILE, "Entering i2c mode\n");
	bhl_enter_bin_i2c();
	fprintf(LOG_FILE, "Setting I2C speed %d khz\n", khz);
	fprintf(LOG_FILE, "speed: 0x%X\n", speed);
	bhl_i2c_speed(speed);
	fprintf(LOG_FILE, "enabling PHS (PULL-UPS and POWER)...\n");
	fprintf(LOG_FILE, "phs: 0x%X\n", phs);
	bhl_set_peripherals(phs);
	Sleep(200);

	if (!just_i2c_scanner)
	{
		return 1;
	}

	i2c_detected = bhl_i2c_scan(i2c_memaux + 0x200);
	if (i2c_detected)
	{
		retf = 1;

		curr = i2c_memaux;
		for (i = 0; i < i2c_detected; i++)
		{
#define BYTE_TO_BINARY_PATTERN "%c%c%c%c%c%c%c%c"
#define BYTE_TO_BINARY(byte)  \
  ((byte) & 0x80 ? '1' : '0'), \
  ((byte) & 0x40 ? '1' : '0'), \
  ((byte) & 0x20 ? '1' : '0'), \
  ((byte) & 0x10 ? '1' : '0'), \
  ((byte) & 0x08 ? '1' : '0'), \
  ((byte) & 0x04 ? '1' : '0'), \
  ((byte) & 0x02 ? '1' : '0'), \
  ((byte) & 0x01 ? '1' : '0') 

			curr += sprintf(curr, BYTE_TO_BINARY_PATTERN " 0x%X(%d) -> 0x%X(%d) %s ----  ",
				BYTE_TO_BINARY(i2c_memaux[0x200 + i] >> 1),
				i2c_memaux[0x200 + i] >> 1, 
				i2c_memaux[0x200 + i] >> 1, 
				i2c_memaux[0x200 + i], 
				i2c_memaux[0x200 + i], 
				(i2c_memaux[0x200 + i] & 0x01) ? "R" : "W");
		}
		curr[0] = ' ';
		curr[1] = 0;
	}
	bhl_asprog_i2c_close();

	return 1;
}

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_close(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	fprintf(LOG_FILE, "bhl_asprog_i2c_close\n");

	if (NULL != com_glb)
	{
		bhl_hard_reset();
		bhl_com_close();
		com_glb = NULL;
	}

	return 1;
}

BUZZPIRATHLP_API unsigned char* __stdcall bhl_asprog_i2c_get_memaux(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	return i2c_memaux;
}


BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_readwrite(unsigned int devaddr, unsigned int size, unsigned char* buffwr, unsigned int size_buffwr)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char high = 0;
	unsigned char low = 0;
	unsigned int i = 0;
	unsigned int j = 0;
	unsigned char recv[100] = { 0 };

	if (end_fast)
	{
		return 0;
	}

	fprintf(LOG_FILE, "\ndevaddr: 0x%X(%d) size: 0x%X(%d) buffwr: 0x%X(%d) size_buffwr: 0x%X(%d)\n", 
		devaddr, devaddr, 
		size, size, 
		buffwr, buffwr, 
		size_buffwr, size_buffwr);

	if (size_buffwr > 4096)
	{
		MessageBoxA(NULL, "size_wbuffer bigger", "size_buffwr bigger", MB_OK | MB_TOPMOST | MB_ICONWARNING);
		return 0;
	}

	if (size_buffwr)
	{
		for (i = 0; i < size_buffwr; i++)
		{
			fprintf(LOG_FILE, "0x%02X ", buffwr[i]);
		}
		fprintf(LOG_FILE, "-\n\n");
	}

	ComWriteByte(com_glb, BHL_I2C_WRITE_THEN_READ, 0);
	ComWriteByte(com_glb, ((size_buffwr + 1) >> 8) & 0x000000FF, 0);
	Sleep(1);
	ComWriteByte(com_glb, (size_buffwr + 1) & 0x000000FF, 0);
	ComWriteByte(com_glb, (size >> 8) & 0x000000FF, 0);
	Sleep(1);
	ComWriteByte(com_glb, size & 0x000000FF, 0);
	Sleep(1);
	ComWriteByte(com_glb, devaddr, 0);
	if (size_buffwr)
	{
		for (i = 0; i < size_buffwr; i++)
		{
			ComWriteByte(com_glb, buffwr[i], 0);
		}
	}
	Sleep(1);

	do
	{ 
		*recv = 0x69;
		ComReadByte(com_glb, &recv, 0);
		if (*recv != 1)
		{
			fprintf(LOG_FILE, "waiting for bus pirate...");
		}
		if (end_fast)
		{
			return 0;
		}
	} while (*recv != 1);

	if (size)
	{
		ComReadBuff(com_glb, i2c_memaux, size, 0);

		if (!gdbglvl || (idblk++ % TIME_DBG_P) == 0)
		{
			fprintf(LOG_FILE, "\n0x%08X  ", 0);
			for (i = 0; i < size; i++)
			{
				fprintf(LOG_FILE, "%02X ", i2c_memaux[i]);
				if ((i + 1) % 8 == 0)
				{
					fprintf(LOG_FILE, "  ");
					for (j = i - 7; j < i; j++)
					{
						fprintf(LOG_FILE, "%c", (i2c_memaux[j] >= 0x20 && i2c_memaux[j] <= 0x7E) ? i2c_memaux[j] : '.');
					}
					if (i + 1 != size)
					{
						fprintf(LOG_FILE, "\n0x%08X  ", i);
					}
				}
			}
			j = i - (size % 8);
			for (; j < i; j++)
			{
				fprintf(LOG_FILE, "%c", (i2c_memaux[j] >= 0x20 && i2c_memaux[j] <= 0x7E) ? i2c_memaux[j] : '.');
			}
			fprintf(LOG_FILE, "\n\n");
		}
	}

	if (gdbglvl)
		Sleep(1);

	return 1;
}

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_start(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char receive_buf[10] = { 0 };

	if (!gdbglvl)
		fprintf(LOG_FILE, "bhl_asprog_i2c_start\n");

	if (end_fast)
	{
		return 0;
	}

	ComWriteByte(com_glb, BHL_I2C_SEND_START, 0);
	ComReadBuff(com_glb, receive_buf, 2, 0);

	return 1;
}


BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_stop(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char receive_buf[10] = { 0 };

	if (!gdbglvl)
		fprintf(LOG_FILE, "bhl_asprog_i2c_stop\n");

	if (end_fast)
	{
		return 0;
	}

	ComWriteByte(com_glb, BHL_I2C_SEND_STOP, 0);
	ComReadBuff(com_glb, receive_buf, 2, 0);

	return 1;
}

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_read_byte(void)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char receive_buf[10] = { 0 };
	unsigned char buff[] = { BHL_I2C_READ_BYTE , BHL_I2C_SEND_ACK };

	if (!gdbglvl)
		fprintf(LOG_FILE, "bhl_asprog_i2c_read_byte\n");

	if (end_fast)
	{
		return 0;
	}

	ComWriteBuff(com_glb, buff, 2, 0);
	ComReadBuff(com_glb, receive_buf, 3, 0);

	*i2c_memaux = receive_buf[0];

	return 1;
}

BUZZPIRATHLP_API unsigned int __stdcall bhl_asprog_i2c_write_byte(unsigned int byte)
{
#pragma comment(linker, "/EXPORT:" __FUNCTION__ "=" __FUNCDNAME__)
	unsigned char receive_buf[10] = { 0 };
	unsigned char buff[] = { BHL_I2C_BULK_WRITE, byte };

	if (!gdbglvl)
		fprintf(LOG_FILE, "bhl_asprog_i2c_write_byte\n");

	if (end_fast)
	{
		return 0;
	}

	ComWriteBuff(com_glb, buff, 2, 0);
	ComReadBuff(com_glb, receive_buf, 3, 0);

	return 1;
}