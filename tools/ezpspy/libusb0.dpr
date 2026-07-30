library libusb0;

{ A logging stand-in for libusb0.dll, to learn how the EZP2023+ vendor
  software performs a write.

  The vendor program imports libusb0.dll statically, so dropping this next
  to its exe makes Windows load this instead (the exe's own directory is
  searched first). Every call is forwarded to the real library in
  C:\Windows\SysWOW64\libusb0.dll and appended to ezpspy.log beside this
  DLL, with endpoint numbers and the leading bytes of each transfer.

  Both transfer paths are covered, because that vendor imports both: the
  synchronous usb_bulk_write / usb_bulk_read, and the asynchronous
  setup/submit/reap trio, where the payload only appears at submit time.

  Nothing is modified in flight -- this only watches. Build 32-bit, since
  the vendor exe is 32-bit:

    C:\lazarus32\fpc\3.2.2\bin\i386-win32\fpc.exe -Twin32 -Pi386 -Mobjfpc ^
        -Sh -olibusb0.dll tools\ezpspy\libusb0.dpr
}

{$mode objfpc}{$H+}

uses
  Windows, SysUtils;

const
  REAL_DLL = 'C:\Windows\SysWOW64\libusb0.dll';
  LOG_NAME = 'ezpspy.log';
  //ต้องเห็นทั้ง 64 ไบต์ของแพ็กเก็ตคำสั่ง: ครั้งก่อนจดแค่ 32 แล้วความ
  //ต่างที่หาอยู่ก็อาจซ่อนอยู่ในครึ่งหลังพอดี
  MAX_DUMP = 64;

type
  TFnInitV      = procedure; cdecl;
  TFnIntV       = function: longint; cdecl;
  TFnPtrV       = function: pointer; cdecl;
  TFnIntP       = function(a: pointer): longint; cdecl;
  TFnPtrP       = function(a: pointer): pointer; cdecl;
  TFnIntPI      = function(a: pointer; b: longint): longint; cdecl;
  TFnIntPPI     = function(a: pointer; b: pointer; c: longint): longint; cdecl;
  TFnBulk       = function(dev: pointer; ep: longint; bytes: pointer;
                           size, timeout: longint): longint; cdecl;
  TFnCtrl       = function(dev: pointer; rt, req, val, idx: longint;
                           bytes: pointer; size, timeout: longint): longint; cdecl;
  TFnSetupAsync = function(dev: pointer; ctx: pointer; ep: longint): longint; cdecl;
  TFnIsoAsync   = function(dev: pointer; ctx: pointer; ep, pkt: longint): longint; cdecl;
  TFnSubmit     = function(ctx: pointer; bytes: pointer; size: longint): longint; cdecl;
  TFnGetDesc    = function(dev: pointer; t, i: longint; buf: pointer;
                           size: longint): longint; cdecl;
  TFnGetDescEp  = function(dev: pointer; ep, t, i: longint; buf: pointer;
                           size: longint): longint; cdecl;
  TFnGetStr     = function(dev: pointer; idx, lang: longint; buf: pointer;
                           len: longint): longint; cdecl;
  TFnGetStrS    = function(dev: pointer; idx: longint; buf: pointer;
                           len: longint): longint; cdecl;
  TFnVoidI      = procedure(a: longint); cdecl;
  TFnIntStr     = function(s: pchar): longint; cdecl;

var
  Lib: THandle = 0;
  LogPath: string = '';
  LogLock: TRTLCriticalSection;

  r_init: TFnInitV = nil;
  r_find_busses: TFnIntV = nil;
  r_find_devices: TFnIntV = nil;
  r_get_busses: TFnPtrV = nil;
  r_open: TFnPtrP = nil;
  r_close: TFnIntP = nil;
  r_device: TFnPtrP = nil;
  r_set_configuration: TFnIntPI = nil;
  r_claim_interface: TFnIntPI = nil;
  r_release_interface: TFnIntPI = nil;
  r_set_altinterface: TFnIntPI = nil;
  r_clear_halt: TFnIntPI = nil;
  r_resetep: TFnIntPI = nil;
  r_reset: TFnIntP = nil;
  r_reset_ex: TFnIntPI = nil;
  r_bulk_write: TFnBulk = nil;
  r_bulk_read: TFnBulk = nil;
  r_interrupt_write: TFnBulk = nil;
  r_interrupt_read: TFnBulk = nil;
  r_control_msg: TFnCtrl = nil;
  r_bulk_setup_async: TFnSetupAsync = nil;
  r_interrupt_setup_async: TFnSetupAsync = nil;
  r_isochronous_setup_async: TFnIsoAsync = nil;
  r_submit_async: TFnSubmit = nil;
  r_reap_async: TFnIntPI = nil;
  r_free_async: TFnIntP = nil;
  r_get_descriptor: TFnGetDesc = nil;
  r_get_descriptor_by_endpoint: TFnGetDescEp = nil;
  r_get_string: TFnGetStr = nil;
  r_get_string_simple: TFnGetStrS = nil;
  r_get_version: TFnPtrV = nil;
  r_strerror: TFnPtrV = nil;
  r_set_debug: TFnVoidI = nil;
  r_install_driver_np: TFnIntStr = nil;
  r_install_service_np: TFnIntV = nil;
  r_uninstall_service_np: TFnIntV = nil;

//---------------------------------------------------------------- logging

procedure Say(const S: string);
var
  F: THandle;
  Line: string;
  Written: DWORD;
begin
  if LogPath = '' then Exit;
  EnterCriticalSection(LogLock);
  try
    F := CreateFile(PChar(LogPath), GENERIC_WRITE, FILE_SHARE_READ, nil,
                    OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
    if F = INVALID_HANDLE_VALUE then Exit;
    SetFilePointer(F, 0, nil, FILE_END);
    Line := S + #13#10;
    WriteFile(F, Line[1], Length(Line), Written, nil);
    CloseHandle(F);
  finally
    LeaveCriticalSection(LogLock);
  end;
end;

function Dump(bytes: pointer; size: longint): string;
var
  i, n: longint;
  p: PByte;
begin
  Result := '';
  if (bytes = nil) or (size <= 0) then Exit;
  p := PByte(bytes);
  n := size;
  if n > MAX_DUMP then n := MAX_DUMP;
  for i := 0 to n - 1 do
    Result := Result + IntToHex(p[i], 2) + ' ';
  if size > MAX_DUMP then Result := Result + '...';
end;

//ปลายทางที่ผูกกับ context ของ async เพื่อให้ตอน submit รู้ว่าไปขาไหน
var
  AsyncCtx: array[0..63] of pointer;
  AsyncEp: array[0..63] of longint;
  AsyncCount: integer = 0;

procedure RememberAsync(ctx: pointer; ep: longint);
begin
  if (ctx = nil) or (AsyncCount > High(AsyncCtx)) then Exit;
  AsyncCtx[AsyncCount] := ctx;
  AsyncEp[AsyncCount] := ep;
  Inc(AsyncCount);
end;

function EpOfAsync(ctx: pointer): longint;
var
  i: integer;
begin
  Result := -1;
  for i := 0 to AsyncCount - 1 do
    if AsyncCtx[i] = ctx then Exit(AsyncEp[i]);
end;

//---------------------------------------------------------------- forwarders

function Bind(const Name: string): pointer;
begin
  Result := nil;
  if Lib <> 0 then Result := GetProcAddress(Lib, PChar(Name));
  if Result = nil then Say('!! real libusb0 has no ' + Name);
end;

procedure usb_init; cdecl;
begin
  Say('usb_init');
  if Assigned(r_init) then r_init();
end;

function usb_find_busses: longint; cdecl;
begin
  Result := 0;
  if Assigned(r_find_busses) then Result := r_find_busses();
  Say(Format('usb_find_busses -> %d', [Result]));
end;

function usb_find_devices: longint; cdecl;
begin
  Result := 0;
  if Assigned(r_find_devices) then Result := r_find_devices();
  Say(Format('usb_find_devices -> %d', [Result]));
end;

function usb_get_busses: pointer; cdecl;
begin
  Result := nil;
  if Assigned(r_get_busses) then Result := r_get_busses();
end;

function usb_open(dev: pointer): pointer; cdecl;
begin
  Result := nil;
  if Assigned(r_open) then Result := r_open(dev);
  Say(Format('usb_open -> %p', [Result]));
end;

function usb_close(dev: pointer): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_close) then Result := r_close(dev);
  Say('usb_close');
end;

function usb_device(dev: pointer): pointer; cdecl;
begin
  Result := nil;
  if Assigned(r_device) then Result := r_device(dev);
end;

function usb_set_configuration(dev: pointer; cfg: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_set_configuration) then Result := r_set_configuration(dev, cfg);
  Say(Format('usb_set_configuration(%d) -> %d', [cfg, Result]));
end;

function usb_claim_interface(dev: pointer; i: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_claim_interface) then Result := r_claim_interface(dev, i);
  Say(Format('usb_claim_interface(%d) -> %d', [i, Result]));
end;

function usb_release_interface(dev: pointer; i: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_release_interface) then Result := r_release_interface(dev, i);
  Say(Format('usb_release_interface(%d) -> %d', [i, Result]));
end;

function usb_set_altinterface(dev: pointer; a: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_set_altinterface) then Result := r_set_altinterface(dev, a);
  Say(Format('usb_set_altinterface(%d) -> %d', [a, Result]));
end;

function usb_clear_halt(dev: pointer; ep: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_clear_halt) then Result := r_clear_halt(dev, ep);
  Say(Format('usb_clear_halt(0x%.2x) -> %d', [ep, Result]));
end;

function usb_resetep(dev: pointer; ep: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_resetep) then Result := r_resetep(dev, ep);
  Say(Format('usb_resetep(0x%.2x) -> %d', [ep, Result]));
end;

function usb_reset(dev: pointer): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_reset) then Result := r_reset(dev);
  Say(Format('usb_reset -> %d', [Result]));
end;

function usb_reset_ex(dev: pointer; t: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_reset_ex) then Result := r_reset_ex(dev, t);
  Say(Format('usb_reset_ex(%d) -> %d', [t, Result]));
end;

function usb_bulk_write(dev: pointer; ep: longint; bytes: pointer;
  size, timeout: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_bulk_write) then
    Result := r_bulk_write(dev, ep, bytes, size, timeout);
  Say(Format('OUT  ep 0x%.2x  %5d bytes  t=%d -> %d   %s',
             [ep, size, timeout, Result, Dump(bytes, size)]));
end;

function usb_bulk_read(dev: pointer; ep: longint; bytes: pointer;
  size, timeout: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_bulk_read) then
    Result := r_bulk_read(dev, ep, bytes, size, timeout);
  Say(Format('IN   ep 0x%.2x  %5d bytes  t=%d -> %d   %s',
             [ep, size, timeout, Result, Dump(bytes, Result)]));
end;

function usb_interrupt_write(dev: pointer; ep: longint; bytes: pointer;
  size, timeout: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_interrupt_write) then
    Result := r_interrupt_write(dev, ep, bytes, size, timeout);
  Say(Format('IOUT ep 0x%.2x  %5d bytes -> %d   %s',
             [ep, size, Result, Dump(bytes, size)]));
end;

function usb_interrupt_read(dev: pointer; ep: longint; bytes: pointer;
  size, timeout: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_interrupt_read) then
    Result := r_interrupt_read(dev, ep, bytes, size, timeout);
  Say(Format('IIN  ep 0x%.2x  %5d bytes -> %d   %s',
             [ep, size, Result, Dump(bytes, Result)]));
end;

function usb_control_msg(dev: pointer; rt, req, val, idx: longint;
  bytes: pointer; size, timeout: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_control_msg) then
    Result := r_control_msg(dev, rt, req, val, idx, bytes, size, timeout);
  Say(Format('CTRL rt=0x%.2x req=0x%.2x val=0x%.4x idx=%d size=%d -> %d  %s',
             [rt, req, val, idx, size, Result, Dump(bytes, Result)]));
end;

function usb_bulk_setup_async(dev: pointer; ctx: pointer;
  ep: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_bulk_setup_async) then
    Result := r_bulk_setup_async(dev, ctx, ep);
  if (ctx <> nil) and (Result >= 0) then
    RememberAsync(PPointer(ctx)^, ep);
  Say(Format('async setup  ep 0x%.2x -> %d', [ep, Result]));
end;

function usb_interrupt_setup_async(dev: pointer; ctx: pointer;
  ep: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_interrupt_setup_async) then
    Result := r_interrupt_setup_async(dev, ctx, ep);
  if (ctx <> nil) and (Result >= 0) then
    RememberAsync(PPointer(ctx)^, ep);
  Say(Format('async isetup ep 0x%.2x -> %d', [ep, Result]));
end;

function usb_isochronous_setup_async(dev: pointer; ctx: pointer;
  ep, pkt: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_isochronous_setup_async) then
    Result := r_isochronous_setup_async(dev, ctx, ep, pkt);
  Say(Format('async isoset ep 0x%.2x -> %d', [ep, Result]));
end;

function usb_submit_async(ctx: pointer; bytes: pointer;
  size: longint): longint; cdecl;
var
  ep: longint;
begin
  Result := 0;
  if Assigned(r_submit_async) then Result := r_submit_async(ctx, bytes, size);
  ep := EpOfAsync(ctx);
  Say(Format('async submit ep 0x%.2x  %5d bytes -> %d   %s',
             [ep, size, Result, Dump(bytes, size)]));
end;

function usb_reap_async(ctx: pointer; timeout: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_reap_async) then Result := r_reap_async(ctx, timeout);
  Say(Format('async reap   ep 0x%.2x  t=%d -> %d',
             [EpOfAsync(ctx), timeout, Result]));
end;

function usb_free_async(ctx: pointer): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_free_async) then Result := r_free_async(ctx);
end;

function usb_get_descriptor(dev: pointer; t, i: longint; buf: pointer;
  size: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_get_descriptor) then
    Result := r_get_descriptor(dev, t, i, buf, size);
end;

function usb_get_descriptor_by_endpoint(dev: pointer; ep, t, i: longint;
  buf: pointer; size: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_get_descriptor_by_endpoint) then
    Result := r_get_descriptor_by_endpoint(dev, ep, t, i, buf, size);
end;

function usb_get_string(dev: pointer; idx, lang: longint; buf: pointer;
  len: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_get_string) then Result := r_get_string(dev, idx, lang, buf, len);
end;

function usb_get_string_simple(dev: pointer; idx: longint; buf: pointer;
  len: longint): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_get_string_simple) then
    Result := r_get_string_simple(dev, idx, buf, len);
end;

function usb_get_version: pointer; cdecl;
begin
  Result := nil;
  if Assigned(r_get_version) then Result := r_get_version();
end;

function usb_strerror: pointer; cdecl;
begin
  Result := nil;
  if Assigned(r_strerror) then Result := r_strerror();
end;

procedure usb_set_debug(level: longint); cdecl;
begin
  if Assigned(r_set_debug) then r_set_debug(level);
end;

function usb_install_driver_np(inf: pchar): longint; cdecl;
begin
  Result := 0;
  if Assigned(r_install_driver_np) then Result := r_install_driver_np(inf);
end;

function usb_install_service_np: longint; cdecl;
begin
  Result := 0;
  if Assigned(r_install_service_np) then Result := r_install_service_np();
end;

function usb_uninstall_service_np: longint; cdecl;
begin
  Result := 0;
  if Assigned(r_uninstall_service_np) then Result := r_uninstall_service_np();
end;

exports
  usb_init name 'usb_init',
  usb_find_busses name 'usb_find_busses',
  usb_find_devices name 'usb_find_devices',
  usb_get_busses name 'usb_get_busses',
  usb_open name 'usb_open',
  usb_close name 'usb_close',
  usb_device name 'usb_device',
  usb_set_configuration name 'usb_set_configuration',
  usb_claim_interface name 'usb_claim_interface',
  usb_release_interface name 'usb_release_interface',
  usb_set_altinterface name 'usb_set_altinterface',
  usb_clear_halt name 'usb_clear_halt',
  usb_resetep name 'usb_resetep',
  usb_reset name 'usb_reset',
  usb_reset_ex name 'usb_reset_ex',
  usb_bulk_write name 'usb_bulk_write',
  usb_bulk_read name 'usb_bulk_read',
  usb_interrupt_write name 'usb_interrupt_write',
  usb_interrupt_read name 'usb_interrupt_read',
  usb_control_msg name 'usb_control_msg',
  usb_bulk_setup_async name 'usb_bulk_setup_async',
  usb_interrupt_setup_async name 'usb_interrupt_setup_async',
  usb_isochronous_setup_async name 'usb_isochronous_setup_async',
  usb_submit_async name 'usb_submit_async',
  usb_reap_async name 'usb_reap_async',
  usb_free_async name 'usb_free_async',
  usb_get_descriptor name 'usb_get_descriptor',
  usb_get_descriptor_by_endpoint name 'usb_get_descriptor_by_endpoint',
  usb_get_string name 'usb_get_string',
  usb_get_string_simple name 'usb_get_string_simple',
  usb_get_version name 'usb_get_version',
  usb_strerror name 'usb_strerror',
  usb_set_debug name 'usb_set_debug',
  usb_install_driver_np name 'usb_install_driver_np',
  usb_install_service_np name 'usb_install_service_np',
  usb_uninstall_service_np name 'usb_uninstall_service_np';

var
  Buf: array[0..MAX_PATH] of char;

begin
  InitCriticalSection(LogLock);
  //log อยู่ข้าง DLL ตัวนี้ ไม่ใช่ในไดเรกทอรีปัจจุบันที่โปรแกรมอาจเปลี่ยน
  if GetModuleFileName(HInstance, Buf, SizeOf(Buf)) > 0 then
    LogPath := ExtractFilePath(string(Buf)) + LOG_NAME;

  Lib := LoadLibrary(REAL_DLL);
  Say('--- ezpspy attached, real libusb0 handle ' + IntToHex(Lib, 8) + ' ---');

  Pointer(r_init) := Bind('usb_init');
  Pointer(r_find_busses) := Bind('usb_find_busses');
  Pointer(r_find_devices) := Bind('usb_find_devices');
  Pointer(r_get_busses) := Bind('usb_get_busses');
  Pointer(r_open) := Bind('usb_open');
  Pointer(r_close) := Bind('usb_close');
  Pointer(r_device) := Bind('usb_device');
  Pointer(r_set_configuration) := Bind('usb_set_configuration');
  Pointer(r_claim_interface) := Bind('usb_claim_interface');
  Pointer(r_release_interface) := Bind('usb_release_interface');
  Pointer(r_set_altinterface) := Bind('usb_set_altinterface');
  Pointer(r_clear_halt) := Bind('usb_clear_halt');
  Pointer(r_resetep) := Bind('usb_resetep');
  Pointer(r_reset) := Bind('usb_reset');
  Pointer(r_reset_ex) := Bind('usb_reset_ex');
  Pointer(r_bulk_write) := Bind('usb_bulk_write');
  Pointer(r_bulk_read) := Bind('usb_bulk_read');
  Pointer(r_interrupt_write) := Bind('usb_interrupt_write');
  Pointer(r_interrupt_read) := Bind('usb_interrupt_read');
  Pointer(r_control_msg) := Bind('usb_control_msg');
  Pointer(r_bulk_setup_async) := Bind('usb_bulk_setup_async');
  Pointer(r_interrupt_setup_async) := Bind('usb_interrupt_setup_async');
  Pointer(r_isochronous_setup_async) := Bind('usb_isochronous_setup_async');
  Pointer(r_submit_async) := Bind('usb_submit_async');
  Pointer(r_reap_async) := Bind('usb_reap_async');
  Pointer(r_free_async) := Bind('usb_free_async');
  Pointer(r_get_descriptor) := Bind('usb_get_descriptor');
  Pointer(r_get_descriptor_by_endpoint) := Bind('usb_get_descriptor_by_endpoint');
  Pointer(r_get_string) := Bind('usb_get_string');
  Pointer(r_get_string_simple) := Bind('usb_get_string_simple');
  Pointer(r_get_version) := Bind('usb_get_version');
  Pointer(r_strerror) := Bind('usb_strerror');
  Pointer(r_set_debug) := Bind('usb_set_debug');
  Pointer(r_install_driver_np) := Bind('usb_install_driver_np');
  Pointer(r_install_service_np) := Bind('usb_install_service_np');
  Pointer(r_uninstall_service_np) := Bind('usb_uninstall_service_np');
end.
