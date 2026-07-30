unit ch347proto;

// The CH347's vendor bulk protocol for SPI, as plain packet arithmetic.
//
// In mode 1 the CH347 exposes SPI/I2C on USB interface 2 as two bulk
// endpoints (OUT 06h, IN 86h). Every exchange is a packet of
// [command][length lo][length hi][payload...], little-endian length of the
// payload alone. The layout here follows the open implementations that
// documented the protocol -- flashrom's ch347_spi and the Linux kernel's
// spi-ch347 -- because WCH never published it. Several configuration bytes
// are cargo-culted by every one of those implementations from the vendor
// driver's traffic ("mystery bytes" below); they are what the real devices
// expect and nobody knows what they mean.
//
// This unit is pure: it builds and parses packets and never touches USB, so
// the byte layout is pinned by tests on every platform. The libusb
// transport that moves these packets lives in ch347usb.pas and only builds
// where libusb exists.
//
// Status: written to the documented protocol, NOT yet validated against a
// live CH347 on Linux. tools/ch347smoke.lpr is the validation harness.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  CH347_USB_VID       = $1A86;
  CH347_USB_PID_MODE1 = $55DB; //UART + SPI/I2C vendor interface
  CH347_USB_PID_MODE3 = $55DE; //SPI/I2C only
  CH347_USB_INTERFACE = 2;
  CH347_EP_OUT        = $06;
  CH347_EP_IN         = $86;

  CH347_CMD_SPI_SET_CFG = $C0;
  CH347_CMD_SPI_CS_CTRL = $C1;
  CH347_CMD_SPI_OUT_IN  = $C2;
  CH347_CMD_SPI_IN      = $C3;
  CH347_CMD_SPI_OUT     = $C4;
  CH347_CMD_SPI_GET_CFG = $CA;

  //One bulk packet, header included; the data phase of one OUT chunk.
  CH347_MAX_PACKET = 510;
  CH347_MAX_DATA   = CH347_MAX_PACKET - 3;

  //CS control nibbles: bit 7 = apply a change, bit 6 = deassert.
  CH347_CS_ASSERT   = $80;
  CH347_CS_DEASSERT = $C0;
  CH347_CS_IGNORE   = $00;

  //Divisor index 0..7: SPI clock = 60 MHz / 2^index. The GUI's CH347 menu
  //tags use the same numbering, which is not a coincidence.
  CH347_DIVISOR_MAX = 7;

function CH347ClockHz(DivisorIndex: byte): cardinal;

//29-byte set-configuration packet (26-byte payload). Mode 0, MSB first,
//CS active low; only the clock divisor varies.
function CH347BuildSPIConfig(DivisorIndex: byte; out Packet: TBytes;
  out ErrorText: string): boolean;

//13-byte CS-control packet driving CS1; CS2 is left alone.
function CH347BuildCSControl(AssertCS: boolean): TBytes;

//Header+data for one write chunk. DataLen must fit one packet.
function CH347BuildSPIOut(const Data: array of byte; Offset: SizeInt;
  DataLen: word): TBytes;

//Request ReadLen bytes clocked in (payload: 32-bit little-endian count).
function CH347BuildSPIInRequest(ReadLen: cardinal): TBytes;

//Split the [cmd][lo][hi] header off a device reply.
function CH347ParseHeader(const Reply: array of byte; ReplyLen: SizeInt;
  out Cmd: byte; out PayloadLen: word): boolean;

//The reply to an OUT chunk: 4 bytes, command echoed, one status byte, 0 = ok.
function CH347OutAckOK(const Reply: array of byte; ReplyLen: SizeInt): boolean;

implementation

function CH347ClockHz(DivisorIndex: byte): cardinal;
begin
  if DivisorIndex > CH347_DIVISOR_MAX then Exit(0);
  Result := cardinal(60000000) shr DivisorIndex;
end;

function CH347BuildSPIConfig(DivisorIndex: byte; out Packet: TBytes;
  out ErrorText: string): boolean;
begin
  Packet := nil;
  ErrorText := '';
  Result := False;
  if DivisorIndex > CH347_DIVISOR_MAX then
  begin
    ErrorText := Format('SPI clock divisor %d is outside 0..%d',
                        [DivisorIndex, CH347_DIVISOR_MAX]);
    Exit;
  end;

  SetLength(Packet, 29);
  FillByte(Packet[0], Length(Packet), 0);
  Packet[0] := CH347_CMD_SPI_SET_CFG;
  Packet[1] := 26;        //payload length, little endian
  Packet[2] := 0;
  //ไบต์ปริศนาที่ทุก implementation เปิดโล่งตั้งตาม vendor driver กันหมด
  Packet[5] := 4;
  Packet[6] := 1;
  //Packet[9] = CPOL ในบิต 1, Packet[11] = CPHA ในบิต 0: SPI mode 0 คือศูนย์
  Packet[14] := 2;        //อีกหนึ่งไบต์ปริศนา
  Packet[15] := (DivisorIndex and $07) shl 3;
  //Packet[17] บิต 7 = LSB first; ศูนย์คือ MSB ก่อน ตามที่แฟลชทุกตัวคุย
  Packet[19] := 7;        //ปริศนาอีกหนึ่ง
  //Packet[24] = ขั้ว CS (บิต 7 CS2, บิต 6 CS1); ศูนย์ = active low
  Result := True;
end;

function CH347BuildCSControl(AssertCS: boolean): TBytes;
begin
  Result := nil;
  SetLength(Result, 13);
  FillByte(Result[0], Length(Result), 0);
  Result[0] := CH347_CMD_SPI_CS_CTRL;
  Result[1] := 10;
  Result[2] := 0;
  if AssertCS then Result[3] := CH347_CS_ASSERT
  else Result[3] := CH347_CS_DEASSERT;
  Result[8] := CH347_CS_IGNORE;
end;

function CH347BuildSPIOut(const Data: array of byte; Offset: SizeInt;
  DataLen: word): TBytes;
begin
  Result := nil;
  if (DataLen = 0) or (DataLen > CH347_MAX_DATA) then Exit;
  if (Offset < 0) or (Offset + DataLen > Length(Data)) then Exit;
  SetLength(Result, 3 + DataLen);
  Result[0] := CH347_CMD_SPI_OUT;
  Result[1] := byte(DataLen);
  Result[2] := byte(DataLen shr 8);
  Move(Data[Offset], Result[3], DataLen);
end;

function CH347BuildSPIInRequest(ReadLen: cardinal): TBytes;
begin
  Result := nil;
  if ReadLen = 0 then Exit;
  SetLength(Result, 7);
  Result[0] := CH347_CMD_SPI_IN;
  Result[1] := 4;
  Result[2] := 0;
  Result[3] := byte(ReadLen);
  Result[4] := byte(ReadLen shr 8);
  Result[5] := byte(ReadLen shr 16);
  Result[6] := byte(ReadLen shr 24);
end;

function CH347ParseHeader(const Reply: array of byte; ReplyLen: SizeInt;
  out Cmd: byte; out PayloadLen: word): boolean;
begin
  Cmd := 0;
  PayloadLen := 0;
  Result := False;
  if (ReplyLen < 3) or (ReplyLen > Length(Reply)) then Exit;
  Cmd := Reply[0];
  PayloadLen := word(Reply[1]) or (word(Reply[2]) shl 8);
  Result := True;
end;

function CH347OutAckOK(const Reply: array of byte; ReplyLen: SizeInt): boolean;
var
  Cmd: byte;
  PayloadLen: word;
begin
  Result := CH347ParseHeader(Reply, ReplyLen, Cmd, PayloadLen) and
            (ReplyLen >= 4) and (Cmd = CH347_CMD_SPI_OUT) and
            (PayloadLen >= 1) and (Reply[3] = 0);
end;

end.
