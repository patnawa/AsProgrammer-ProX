unit msgstr;

{$mode objfpc}{$H+}

interface

resourcestring
  STR_CHECK_SETTINGS     = 'Проверьте настройки';
  STR_READING_FLASH      = 'Читаю флэшку...';
  STR_WRITING_FLASH      = 'Записываю флэшку...';
  STR_WRITING_FLASH_WCHK = 'Записываю флэшку с проверкой...';
  STR_CONNECTION_ERROR   = 'Ошибка подключения к ';
  STR_SET_SPEED_ERROR    = 'Ошибка установки скорости SPI';
  STR_WRONG_BYTES_READ   = 'Количество прочитанных байт не равно размеру флэшки';
  STR_WRONG_BYTES_WRITE  = 'Количество записанных байт не равно размеру флэшки';
  STR_WRONG_FILE_SIZE    = 'Размер файла больше размера чипа';
  STR_ERASING_FLASH      = 'Стираю флэшку...';
  STR_DONE               = 'Готово';
  STR_BLOCK_EN           = 'Возможно включена защита на запись. Нажмите кнопку "Снять защиту" и сверьтесь с даташитом';
  STR_VERIFY_ERROR       = 'Ошибка сравнения по адресу: ';
  STR_VERIFY             = 'Проверяю флэшку...';
  STR_TIME               = 'Время выполнения: ';
  STR_USER_CANCEL        = 'Прервано пользователем';
  STR_NO_EEPROM_SUPPORT  = 'Данная версия прошивки не поддерживается!';
  STR_MINI_EEPROM_SUPPORT= 'Данная версия прошивки не поддерживает I2C и MW!';
  STR_I2C_NO_ANSWER      = 'Микросхема не отвечает';
  STR_COMBO_WARN         = 'Чип будет стерт и перезаписан. Продолжить?';
  STR_SEARCH_HEX         = 'Поиск HEX значения';
  STR_GOTO_ADDR          = 'Перейти по адресу';
  STR_NEW_SREG           = 'Стало Sreg: ';
  STR_OLD_SREG           = 'Было Sreg: ';
  STR_START_WRITE        = 'Начать запись?';
  STR_START_ERASE        = 'Точно стереть чип?';
  STR_45PAGE_STD         = 'Установлен стандартный размер страницы';
  STR_45PAGE_POWEROF2    = 'Установлен размер страницы кратный двум!';
  STR_ID_UNKNOWN         = '(Неизвестно)';
  STR_SPECIFY_HEX        = 'Укажите шестнадцатеричные числа';
  STR_NOT_FOUND_HEX      = 'Значение не найдено';
  STR_USB_TIMEOUT        = 'USB_control_msg отвалился по таймауту!';
  STR_SIZE               = 'Размер: ';
  STR_CHANGED            = 'Изменен';
  STR_CURR_HW            = 'Используется программатор: ';
  STR_USING_SCRIPT       = 'Используется скрипт: ';
  STR_DLG_SAVEFILE       = 'Сохранить изменения?';
  STR_DLG_FILECHGD       = 'файл изменён';
  STR_SCRIPT_NO_SECTION  = 'Нет секции: ';
  STR_SCRIPT_SEL_SECTION = 'Выберите секцию';
  STR_SCRIPT_RUN_SECTION = 'Выполняется секция: ';
  STR_ERASE_NOTICE       = 'Процесс может длиться больше минуты на больших флешках!';

  //ข้อความที่เพิ่มเข้ามาใน ProX
  STR_SECTOR_SPI25_ONLY  = 'Sector erase is available only for SPI 25 series chips';
  STR_ERASE_RANGE_Q      = 'Erase the selected address range?';
  STR_ERASING_RANGE      = 'Erasing range: ';
  STR_ERASE_RANGE_EMPTY  = 'Nothing to erase: load a file or set a range first';
  STR_CHECKSUM           = 'Checksum: ';
  STR_CHECKSUM_EMPTY     = 'Buffer is empty, nothing to checksum';
  STR_SFDP_READING       = 'Reading SFDP...';
  STR_SFDP_NOT_FOUND     = 'SFDP is not supported by this chip (no valid signature)';
  STR_SFDP_FOUND         = 'SFDP detected';
  STR_SFDP_APPLIED       = 'Chip settings filled from SFDP';
  STR_FILE_LOADED        = 'File loaded: ';
  STR_FILE_SAVED         = 'File saved: ';
  STR_FILL_BUFFER        = 'Fill buffer';
  STR_FILL_VALUE_HEX     = 'Fill value (hex byte)';
  STR_ID_MISMATCH        = 'Chip ID does not match the selected chip: expected ';
  STR_ID_MISMATCH_Q      = 'The chip in the socket does not match the selected one.'
                         + LineEnding + 'Continue anyway?';
  STR_ID_OK              = 'Chip ID matches: ';
  STR_BACKUP_MAKING      = 'Backing up the chip first...';
  STR_BACKUP_DONE        = 'Backup saved: ';
  STR_BACKUP_FAILED      = 'Backup failed, operation aborted';
  STR_COMPARE_READING    = 'Reading the chip to compare...';
  STR_COMPARE_EQUAL      = 'Buffer and chip are identical';
  STR_COMPARE_DIFF       = 'Different bytes: ';
  STR_COMPARE_RANGES     = 'Differing ranges (first 20):';
  STR_SWAP_DONE          = 'Byte order swapped, 16-bit words: ';
  STR_PROJECT_SAVED      = 'Project saved: ';
  STR_PROJECT_LOADED     = 'Project loaded: ';
  STR_PROJECT_FAILED     = 'Project file error';
  STR_PROD_SAVED         = 'Serial number and production settings updated';
  STR_BATCH_DISABLED     = 'Enable batch mode first: Options -> Serial number and production';
  STR_BATCH_START        = 'Production batch started, chips to program: ';
  STR_BATCH_INSERT       = 'Insert chip %d of %d, then press OK';
  STR_BATCH_UNIT_OK      = 'Chip %d: OK';
  STR_BATCH_UNIT_FAIL    = 'Chip %d: FAILED';
  STR_BATCH_SUMMARY      = 'Batch finished. Done %d, passed %d, failed %d';
  STR_SERIAL_WRITTEN     = 'Serial number written: ';
  STR_SERIAL_NOFIT       = 'Serial number does not fit in the buffer, skipped';
  STR_UNIQUE_ID          = 'Unique ID (4Bh): ';
  STR_SECREG_HEADER      = 'Security register %d at 0x%.6x:';
  STR_SECREG_BLANK       = 'Security register %d at 0x%.6x: blank (all FF)';
  STR_ERASE_TOO_FAST     = 'Erase finished suspiciously fast. The chip may still be write '
                         + 'protected - check the status register and the WP pin';
  STR_AUTH_NOT_SUPPORTED = 'Authentication flash (96h): no response, this is not a W74M part';
  STR_AUTH_STATUS        = 'Authentication flash status (96h): 0x';
  STR_AUTH_COUNTER       = 'Last returned counter data: ';
  STR_AUTH_NEEDS_KEY     = 'Counter and key commands (9Bh) are HMAC-SHA-256 signed and '
                         + 'cannot be used without the root key';
  STR_NO_CHIP            = 'No chip answered. Check the socket, the orientation of pin 1, '
                         + 'the cable and the supply voltage';
  STR_DETECT_ONE         = 'Chip detected and selected: ';
  STR_DETECT_MANY        = 'This ID matches %d chips, pick the right one from the list';
  STR_DETECT_NONE        = 'This ID is not in chiplist.xml and the chip has no SFDP table. '
                         + 'Set size and page size by hand, or add the chip to chiplist.xml';
  STR_DETECT_SFDP        = 'Not in chiplist.xml, falling back to SFDP';
  STR_VENDOR             = 'Manufacturer: ';
  STR_NO_CHIP_SELECTED   = 'No chip selected.'#13#10'Pick one from the IC menu, or press Read ID.';
  STR_HW_CONNECTED       = 'Programmer connected: ';
  STR_HW_DISCONNECTED    = 'No programmer connected';
  STR_HW_SWITCHED        = 'Switched to the programmer that is actually plugged in: ';
  STR_LED_PROGRAMMER     = 'Programmer';
  STR_LED_CHIP           = 'Chip';
  STR_PKG_UNKNOWN        = 'select a chip';
  STR_DRIVER_HINT        = 'If the programmer is plugged in, its driver is probably missing. '
                         + 'Install it from ';
  STR_DRIVER_HINT_COM    = 'Check the COM port setting and that no other program is holding '
                         + 'the port open';

implementation

end.

