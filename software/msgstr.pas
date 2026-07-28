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
  STR_ID_NO_ANSWER       = 'No chip answered the id commands. Nothing was read back, '
                         + 'so there is no id to compare. This is what a loose clip, '
                         + 'an empty socket, a chip fitted the wrong way round or an '
                         + 'unpowered chip all look like';
  STR_ID_NO_ANSWER_Q     = 'No chip is answering. Nothing was read back from the socket.'
                         + LineEnding + LineEnding
                         + 'Check the clip or socket contact, the orientation and the '
                         + 'supply, then press Read ID again.'
                         + LineEnding + LineEnding + 'Continue anyway?';
  STR_ID_OK              = 'Chip ID matches: ';
  STR_BACKUP_MAKING      = 'Backing up the chip first...';
  STR_BACKUP_DONE        = 'Backup saved: ';
  STR_BACKUP_FAILED      = 'Backup failed, operation aborted';
  STR_BACKUP_SKIPPED     = 'Auto-backup covers SPI 25-series chips only; skipping the backup for this chip';
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
  STR_CMP_PICK_FIRST     = 'Pick the first file';
  STR_CMP_PICK_SECOND    = 'Pick the second file';
  STR_CMP_FILES          = 'Comparing two files:';
  STR_CMP_SIZE_DIFF      = 'Sizes differ, comparing the common part only. Difference: ';
  STR_CMP_READ_FIRST     = 'Reading the first chip...';
  STR_CMP_READ_SECOND    = 'Reading the second chip...';
  STR_CMP_SWAP           = 'Now swap in the second chip, then press OK.';
  STR_HINT_KEYS          = 'F5 detect   Ctrl+O open   Esc cancel   F1 console';
  STR_WORKFLOW_TITLE     = 'Safe workflow';
  STR_WORKFLOW_DETECT    = '1  Detect chip';
  STR_WORKFLOW_OPEN      = '2  Open image';
  STR_WORKFLOW_SMART     = '3  Smart write';
  STR_WORKFLOW_READ      = 'Read chip';
  STR_WORKFLOW_VERIFY    = 'Verify';
  STR_WORKFLOW_CONNECT   = 'Next: connect a programmer';
  STR_WORKFLOW_PICK_CHIP = 'Next: detect or select a chip';
  STR_WORKFLOW_PICK_LIST = 'Next: pick the chip from the list (Read ID is SPI only)';
  STR_WORKFLOW_LOAD      = 'Next: open an image or read the chip';
  STR_WORKFLOW_READY     = 'Ready for Smart write';
  STR_WORKFLOW_LEGACY    = 'Ready - this memory type writes with the Write button';
  STR_WORKFLOW_RUNNING   = 'Operation in progress - Esc cancels safely';
  //ปัญหาที่เดิมรู้ตัวหลังกดเขียนไปแล้ว ตอนนี้บอกตั้งแต่ยังไม่กด
  STR_WORKFLOW_NO_SIZE   = 'Next: set the chip size';
  STR_WORKFLOW_BAD_ADDR  = 'The start address is not a hexadecimal number';
  STR_WORKFLOW_TOO_BIG   = 'The image is %d bytes but only %d fit from 0x%s';
  STR_WORKFLOW_MW_ODD    = 'MicroWire Smart write needs an even start address and length';
  STR_WORKFLOW_BAD_PAGE  = 'Next: set a page size between 1 and 2048 bytes';
  //ชิปใหม่กับชิปเก่าต่างกันตรงที่ "มีอะไรให้เสียไหม" ซึ่งเดิมแถบนี้ไม่รู้เลย
  STR_WF_CHIP_PICKED     = 'Chip chosen by hand, not identified - press Detect chip to confirm';
  STR_WF_UNREAD          = 'Ready, but the chip has not been read - you do not know what is on it';
  STR_WF_BLANK           = 'Chip reads blank - nothing to lose, ready to write';
  STR_WF_HASDATA_BACKUP  = 'Chip HAS DATA and it will be backed up first';
  STR_WF_HASDATA_NOBAK   = 'Chip HAS DATA and auto-backup is OFF - it will be lost';
  STR_WF_HASDATA_NOBAK2  = 'Chip HAS DATA and this family cannot be auto-backed up';
  STR_WF_SAME_AS_CHIP    = 'Buffer was read from this chip - writing it back changes nothing';
  STR_WF_FROM_FILE       = 'from %s';
  STR_WF_EDITED          = 'buffer edited by hand';
  STR_COMPARE_SEE_LOG    = 'The differing ranges are listed in the log below,'#13#10
                         + 'and highlighted in the editor.';
  STR_DIFF_IN_EDITOR     = 'The editor shows the second side, with the differing bytes highlighted';
  STR_DIFF_TOO_MANY      = 'Too many differences to highlight them all, stopped early';
  STR_BUSY_TIMEOUT       = 'The chip stayed busy for more than %d seconds. Giving up. '
                         + 'Check the wiring, the supply voltage and the write protection';
  STR_NOT_RESPONDING     = 'No chip is answering. The status register reads back as FF, '
                         + 'which is what an empty socket looks like. Check that the chip '
                         + 'is seated the right way round, powered, and that CS is wired';
  STR_WPS_SCANNING       = 'WPS is set, so the individual block locks decide. Reading them';
  STR_WPS_LOCKED         = 'Block 0x%.8x is locked by its own lock bit';
  STR_WPS_UNREADABLE     = 'WPS is set but the block lock bits could not be read (3Dh). '
                         + 'Whether the target area is protected is unknown';
  STR_WPS_CLEAR          = 'Block locks checked: no locked block covers the target area';
  STR_4B_NATIVE          = 'Using the chip''s own four byte opcodes, no mode switch needed';
  STR_ERASE_MAP          = 'Erase plan from the SFDP sector map: %d commands covering '
                         + '0x%.8x - 0x%.8x';
  STR_PAGE_RETRY         = 'Page verify failed, writing it again. Attempt ';
  STR_VOLT_WARN          = 'This chip is a 1.8 V part.'#13#10#13#10
                         + 'The selected programmer does not supply 1.8 V. Powering the chip '
                         + 'from 3.3 V or 5 V will destroy it.'#13#10#13#10
                         + 'Only continue if the chip is powered from an external 1.8 V supply '
                         + 'with all grounds tied together.'#13#10#13#10
                         + 'Continue?';
  STR_VOLT_ABORTED       = 'Aborted because of the supply voltage';
  STR_NOT_BLANK          = 'The chip is not blank at 0x';
  STR_NOT_BLANK_Q        = 'The area to be written is not erased.'#13#10
                         + 'Writing over data that is not erased usually fails.'#13#10#13#10
                         + 'Continue anyway?';
  STR_BLANK_CHECKING     = 'Checking that the target area is erased...';
  STR_PROT_HEADER        = 'Status register: SR1=0x%.2x  SR2=0x%.2x';
  STR_PROT_RANGE         = 'Protected: 0x%.8x - 0x%.8x  (%d KB)';
  STR_PROT_NONE          = 'Nothing is write protected';
  STR_PROT_CAVEAT        = 'Bit layout read as Winbond W25Q, which most makers follow. '
                         + 'Check the datasheet for anything unusual';
  STR_PROT_LAYOUT        = 'Protection bit layout: %s';
  STR_PROT_EXTENT_UNKNOWN= 'Something is protected on this chip, but the extent cannot be '
                         + 'read from the status register alone on this vendor. Treating '
                         + 'it as protected';

  //--- 4.4 ---
  STR_WREN_REFUSED       = 'The chip did not accept write enable: WEL stayed clear. '
                         + 'That is what a WP# pin held low, a locked status register or '
                         + 'a bad connection looks like. Nothing was written';
  STR_CHIP_REPORTED_FAIL = 'The chip reported a failure: %s';
  STR_SR_LOCK            = 'Status register protection: %s';
  STR_FAST_READ          = 'Reading with the fast read opcode 0x%.2x';
  STR_RESETTING          = 'Resetting the chip before starting';
  STR_QPI_RECOVER        = 'The id read back as all %.2x. Trying a QPI exit and a reset in '
                         + 'case another tool left the chip in a mode it cannot answer in';
  STR_CONTACT_CHECKING   = 'Checking the connection is stable...';
  STR_CONTACT_UNSTABLE   = 'The chip id changed between reads (%s then %s). The connection '
                         + 'is not reliable: reseat the clip, shorten the cable or lower '
                         + 'the clock. Nothing was done';
  STR_CONTACT_OK         = 'Connection stable: the id read back the same %d times';
  STR_BLANK_AFTER_ERASE  = 'Checking the erase actually took...';
  STR_ERASE_DID_NOT_TAKE = 'The erase did not take: 0x%.8x still reads 0x%.2x. The chip '
                         + 'accepted the command and ignored it, which means it is still '
                         + 'protected';
  STR_READ_PASS          = 'Read pass %d of %d';
  STR_READ_UNSTABLE      = 'The two reads of this chip disagree in %d bytes, first at '
                         + '0x%.8x. One of them is wrong and there is no way to tell which. '
                         + 'Reseat the clip and lower the clock';
  STR_READ_STABLE        = 'Both reads agree, so the dump can be trusted';
  STR_IMG_STATS          = 'Dump: %s';
  STR_IMG_KIND           = 'The dump looks like a %s';
  STR_IMG_SUSPECT        = 'Suspicious dump: %s';
  STR_TIMEOUT_FROM_CHIP  = 'Busy ceilings taken from the chip: page %d ms, erase %d ms, '
                         + 'chip erase %d ms';
  STR_GLOBAL_UNLOCK      = 'WPS is set, so the block protect bits decide nothing. '
                         + 'Releasing the individual block locks as well (98h)';
  STR_UNLOCK_FAILED      = 'The chip accepted the unlock and stayed protected. Check '
                         + 'the WP# pin, and whether this part needs its configuration '
                         + 'register changed too';
  STR_UNLOCK_OK          = 'Unlocked: nothing on this chip is write protected now';
  STR_QE_KEPT            = 'Quad enable was left set, as it was before';
  STR_OTP_TITLE          = 'Security register';
  STR_OTP_WHICH          = 'Which register, 1 to 3?';
  STR_OTP_ERASE_Q        = 'Erase it instead of writing to it?';
  STR_OTP_NEED_256       = 'The editor needs at least 256 bytes: its first 256 bytes are written';
  STR_OTP_CONFIRM        = 'Security register %d can be locked permanently, and once locked '
                         + 'nothing can change it again.'#13#10#13#10'Continue?';
  STR_OTP_WRITING        = 'Writing security register %d...';
  STR_OTP_ERASING        = 'Erasing security register %d...';
  STR_DRIVER_HINT        = 'If the programmer is plugged in, its driver is probably missing. '
                         + 'Install it from ';
  STR_DRIVER_HINT_COM    = 'Check the COM port setting and that no other program is holding '
                         + 'the port open';

  //--- ด่านตรวจบิตป้องกันการเขียน ---
  STR_GUARD_BLOCKED      = 'The area to be changed is write protected: 0x%.8x - 0x%.8x';
  STR_GUARD_Q            = 'Part of the area you are about to change is write protected '
                         + 'by the status register.'#13#10#13#10
                         + 'The chip will silently ignore the erase or the write, and the '
                         + 'result will look like a verify failure.'#13#10#13#10
                         + 'Press "Unprotect" first. Continue anyway?';
  STR_GUARD_REFUSED      = 'Refusing to continue while the target area is write protected. '
                         + 'Press "Unprotect" first, or pass --force';
  STR_GUARD_SRP1         = 'SRP1 is set: the status register is locked by hardware and '
                         + 'software cannot unprotect this chip';
  STR_GUARD_OK           = 'Write protection checked: the target area is writable';

  //--- ผลของงาน ---
  STR_OP_RESULT          = 'Result: ';

  //--- SFDP เพิ่มเติม ---
  STR_SFDP_4B_ENTRY      = '  4 byte address mode: ';
  STR_SFDP_4B_OPCODES    = '  4 byte opcodes: read 0x%.2x, page program 0x%.2x';
  STR_SFDP_SR_WREN       = '  Status register write enable: 0x%.2x';
  STR_SFDP_RESET         = '  Soft reset: ';
  STR_SFDP_MAP_HEADER    = '  Sector map: %d regions, %s';
  STR_SFDP_MAP_UNIFORM   = 'uniform';
  STR_SFDP_MAP_MIXED     = 'NOT uniform - this chip has boot blocks of a different size';
  STR_SFDP_MAP_REGION    = '    region %d: %d bytes, erase %d bytes with 0x%.2x';

  //--- บันทึกชิปลงตารางของผู้ใช้ ---
  STR_CHIPSAVE_Q         = 'Save this chip into %s so it is picked up next time?';
  STR_CHIPSAVE_OK        = 'Chip saved into ';
  STR_CHIPSAVE_FAIL      = 'Could not save the chip: ';
  STR_CHIPSAVE_NONAME    = 'Name for the new chip entry';

  //--- การตามรอยการผลิต ---
  STR_PROD_UID_SEEN      = 'This chip has already been programmed and logged as passed. '
                         + 'Unique ID: ';
  STR_PROD_LOGGED        = 'Production log updated: ';
  STR_PROD_LOG_FAIL      = 'Could not write the production log: ';
  STR_JOB_LOADED         = 'Job file loaded: ';
  STR_JOB_FAILED         = 'Job file rejected the buffer: ';
  STR_JOB_OK             = 'Job file check passed';

implementation

end.

