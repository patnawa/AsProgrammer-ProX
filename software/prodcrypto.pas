unit prodcrypto;

// Cryptographic primitives used by the production-job foundation.
//
// This unit deliberately does not implement SHA-256 or a signature algorithm.
// On Windows it delegates SHA-256 and HMAC-SHA-256 to CNG (bcrypt.dll); on
// other platforms to OpenSSL's libcrypto, loaded at runtime.  Both are the
// operating system's own maintained implementations.  HMAC is used as a
// detached, symmetric authenticator for production jobs.  See
// docs/production-job-security.md for the exact security model and
// key-management requirements.
//
// The unit has no LCL dependency and can be linked into a console test.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  SHA256_BYTES = 32;
  SHA256_HEX_CHARS = SHA256_BYTES * 2;
  MIN_HMAC_KEY_BYTES = 32;

type
  TSHA256Digest = array[0..SHA256_BYTES - 1] of byte;

function SHA256Bytes(const Data: TBytes; out Digest: TSHA256Digest;
  out ErrMsg: string): boolean;
function SHA256Stream(Stream: TStream; out Digest: TSHA256Digest;
  out ErrMsg: string): boolean;
function SHA256File(const FileName: string; out Digest: TSHA256Digest;
  out ErrMsg: string): boolean;

function HMACSHA256(const Key, Data: TBytes; out MAC: TSHA256Digest;
  out ErrMsg: string): boolean;

function DigestToHex(const Digest: TSHA256Digest): string;
function HexToDigest(const Hex: string; out Digest: TSHA256Digest): boolean;
function BytesToHex(const Data: TBytes): string;
function HexToBytes(const Hex: string; out Data: TBytes): boolean;

// Compares all bytes even after finding a difference.  This is used for MAC
// verification so that mismatch position is not reflected in normal timing.
function DigestEqualConstantTime(const A, B: TSHA256Digest): boolean;

// Best-effort clearing for caller-owned temporary key buffers.
procedure ClearSensitiveBytes(var Data: TBytes);

implementation

{$IFDEF WINDOWS}
uses
  Windows;

type
  NTSTATUS = LongInt;
  BCRYPT_ALG_HANDLE = Pointer;
  BCRYPT_HASH_HANDLE = Pointer;

const
  BCRYPT_ALG_HANDLE_HMAC_FLAG = $00000008;

function BCryptOpenAlgorithmProvider(out Algorithm: BCRYPT_ALG_HANDLE;
  AlgorithmID, ProviderImplementation: PWideChar;
  Flags: cardinal): NTSTATUS; stdcall;
  external 'bcrypt.dll';
function BCryptCloseAlgorithmProvider(Algorithm: BCRYPT_ALG_HANDLE;
  Flags: cardinal): NTSTATUS; stdcall; external 'bcrypt.dll';
function BCryptGetProperty(Obj: Pointer; PropertyName: PWideChar;
  Output: PByte; OutputSize: cardinal; out ResultSize: cardinal;
  Flags: cardinal): NTSTATUS; stdcall; external 'bcrypt.dll';
function BCryptCreateHash(Algorithm: BCRYPT_ALG_HANDLE;
  out Hash: BCRYPT_HASH_HANDLE; HashObject: PByte; HashObjectSize: cardinal;
  Secret: PByte; SecretSize: cardinal; Flags: cardinal): NTSTATUS; stdcall;
  external 'bcrypt.dll';
function BCryptHashData(Hash: BCRYPT_HASH_HANDLE; Input: PByte;
  InputSize, Flags: cardinal): NTSTATUS; stdcall; external 'bcrypt.dll';
function BCryptFinishHash(Hash: BCRYPT_HASH_HANDLE; Output: PByte;
  OutputSize, Flags: cardinal): NTSTATUS; stdcall; external 'bcrypt.dll';
function BCryptDestroyHash(Hash: BCRYPT_HASH_HANDLE): NTSTATUS; stdcall;
  external 'bcrypt.dll';

function StatusText(const Context: string; Status: NTSTATUS): string;
begin
  Result := Format('%s failed (CNG status 0x%.8x)',
                   [Context, cardinal(Status)]);
end;

function OpenSHA256Provider(HMAC: boolean; out Algorithm: BCRYPT_ALG_HANDLE;
  out ObjectSize: cardinal; out ErrMsg: string): boolean;
var
  Status: NTSTATUS;
  Returned, DigestSize: cardinal;
  AlgorithmName, ObjectProperty, DigestProperty: UnicodeString;
begin
  Result := False;
  ErrMsg := '';
  Algorithm := nil;
  ObjectSize := 0;

  AlgorithmName := 'SHA256';
  ObjectProperty := 'ObjectLength';
  DigestProperty := 'HashDigestLength';

  if HMAC then
    Status := BCryptOpenAlgorithmProvider(Algorithm,
      PWideChar(AlgorithmName), nil, BCRYPT_ALG_HANDLE_HMAC_FLAG)
  else
    Status := BCryptOpenAlgorithmProvider(Algorithm,
      PWideChar(AlgorithmName), nil, 0);
  if Status <> 0 then
  begin
    ErrMsg := StatusText('BCryptOpenAlgorithmProvider', Status);
    Exit;
  end;

  Status := BCryptGetProperty(Algorithm, PWideChar(ObjectProperty),
    PByte(@ObjectSize), SizeOf(ObjectSize), Returned, 0);
  if (Status <> 0) or (Returned <> SizeOf(ObjectSize)) or (ObjectSize = 0) then
  begin
    if Status <> 0 then
      ErrMsg := StatusText('BCryptGetProperty(ObjectLength)', Status)
    else
      ErrMsg := 'CNG returned an invalid SHA-256 object length';
    BCryptCloseAlgorithmProvider(Algorithm, 0);
    Algorithm := nil;
    Exit;
  end;

  DigestSize := 0;
  Status := BCryptGetProperty(Algorithm, PWideChar(DigestProperty),
    PByte(@DigestSize), SizeOf(DigestSize), Returned, 0);
  if (Status <> 0) or (Returned <> SizeOf(DigestSize)) or
     (DigestSize <> SHA256_BYTES) then
  begin
    if Status <> 0 then
      ErrMsg := StatusText('BCryptGetProperty(HashDigestLength)', Status)
    else
      ErrMsg := Format('CNG reported a %d-byte SHA-256 digest', [DigestSize]);
    BCryptCloseAlgorithmProvider(Algorithm, 0);
    Algorithm := nil;
    Exit;
  end;

  Result := True;
end;

function HashMemory(const Data: TBytes; const Key: TBytes; UseHMAC: boolean;
  out Digest: TSHA256Digest; out ErrMsg: string): boolean;
var
  Algorithm: BCRYPT_ALG_HANDLE;
  Hash: BCRYPT_HASH_HANDLE;
  HashObject: TBytes;
  ObjectSize: cardinal;
  Status: NTSTATUS;
  Secret: PByte;
begin
  Result := False;
  FillChar(Digest, SizeOf(Digest), 0);
  ErrMsg := '';

  if UseHMAC and (Length(Key) < MIN_HMAC_KEY_BYTES) then
  begin
    ErrMsg := Format('HMAC key must contain at least %d bytes',
                     [MIN_HMAC_KEY_BYTES]);
    Exit;
  end;

  if not OpenSHA256Provider(UseHMAC, Algorithm, ObjectSize, ErrMsg) then Exit;
  Hash := nil;
  SetLength(HashObject, ObjectSize);
  try
    if UseHMAC then
      Secret := @Key[0]
    else
      Secret := nil;

    Status := BCryptCreateHash(Algorithm, Hash, @HashObject[0], ObjectSize,
      Secret, Length(Key), 0);
    if Status <> 0 then
    begin
      ErrMsg := StatusText('BCryptCreateHash', Status);
      Exit;
    end;

    if Length(Data) > 0 then
    begin
      Status := BCryptHashData(Hash, @Data[0], Length(Data), 0);
      if Status <> 0 then
      begin
        ErrMsg := StatusText('BCryptHashData', Status);
        Exit;
      end;
    end;

    Status := BCryptFinishHash(Hash, @Digest[0], SizeOf(Digest), 0);
    if Status <> 0 then
    begin
      ErrMsg := StatusText('BCryptFinishHash', Status);
      FillChar(Digest, SizeOf(Digest), 0);
      Exit;
    end;

    Result := True;
  finally
    if Hash <> nil then BCryptDestroyHash(Hash);
    BCryptCloseAlgorithmProvider(Algorithm, 0);
    ClearSensitiveBytes(HashObject);
  end;
end;

function SHA256Bytes(const Data: TBytes; out Digest: TSHA256Digest;
  out ErrMsg: string): boolean;
var
  EmptyKey: TBytes;
begin
  SetLength(EmptyKey, 0);
  Result := HashMemory(Data, EmptyKey, False, Digest, ErrMsg);
end;

function SHA256Stream(Stream: TStream; out Digest: TSHA256Digest;
  out ErrMsg: string): boolean;
const
  CHUNK_SIZE = 64 * 1024;
var
  Algorithm: BCRYPT_ALG_HANDLE;
  Hash: BCRYPT_HASH_HANDLE;
  HashObject, Buffer: TBytes;
  ObjectSize: cardinal;
  Status: NTSTATUS;
  Got: LongInt;
begin
  Result := False;
  FillChar(Digest, SizeOf(Digest), 0);
  ErrMsg := '';
  if Stream = nil then
  begin
    ErrMsg := 'cannot hash a nil stream';
    Exit;
  end;

  if not OpenSHA256Provider(False, Algorithm, ObjectSize, ErrMsg) then Exit;
  Hash := nil;
  SetLength(HashObject, ObjectSize);
  SetLength(Buffer, CHUNK_SIZE);
  try
    try
      Status := BCryptCreateHash(Algorithm, Hash, @HashObject[0], ObjectSize,
        nil, 0, 0);
      if Status <> 0 then
      begin
        ErrMsg := StatusText('BCryptCreateHash', Status);
        Exit;
      end;

      repeat
        Got := Stream.Read(Buffer[0], Length(Buffer));
        if Got < 0 then
        begin
          ErrMsg := 'stream returned a negative read length';
          Exit;
        end;
        if Got > 0 then
        begin
          Status := BCryptHashData(Hash, @Buffer[0], Got, 0);
          if Status <> 0 then
          begin
            ErrMsg := StatusText('BCryptHashData', Status);
            Exit;
          end;
        end;
      until Got = 0;

      Status := BCryptFinishHash(Hash, @Digest[0], SizeOf(Digest), 0);
      if Status <> 0 then
      begin
        ErrMsg := StatusText('BCryptFinishHash', Status);
        FillChar(Digest, SizeOf(Digest), 0);
        Exit;
      end;

      Result := True;
    except
      on E: Exception do
      begin
        ErrMsg := 'cannot hash stream: ' + E.Message;
        FillChar(Digest, SizeOf(Digest), 0);
        Result := False;
      end;
    end;
  finally
    if Hash <> nil then BCryptDestroyHash(Hash);
    BCryptCloseAlgorithmProvider(Algorithm, 0);
    ClearSensitiveBytes(HashObject);
    ClearSensitiveBytes(Buffer);
  end;
end;

function SHA256File(const FileName: string; out Digest: TSHA256Digest;
  out ErrMsg: string): boolean;
var
  Stream: TFileStream;
begin
  Result := False;
  FillChar(Digest, SizeOf(Digest), 0);
  ErrMsg := '';
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      Result := SHA256Stream(Stream, Digest, ErrMsg);
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
      ErrMsg := 'cannot hash "' + FileName + '": ' + E.Message;
  end;
end;

function HMACSHA256(const Key, Data: TBytes; out MAC: TSHA256Digest;
  out ErrMsg: string): boolean;
begin
  Result := HashMemory(Data, Key, True, MAC, ErrMsg);
end;

{$ELSE}

// Non-Windows: delegate to OpenSSL's libcrypto (EVP SHA-256 and one-shot
// HMAC), resolved at runtime.  Same rule as the Windows side: this project
// contains no handwritten cryptographic primitive; the operating system's
// library does the work.  If libcrypto cannot be loaded, every operation
// fails closed with a typed error text rather than a link-time crash.

uses
  dynlibs;

type
  PEVP_MD = Pointer;
  PEVP_MD_CTX = Pointer;

var
  CryptoLib: TLibHandle = NilHandle;
  CryptoLoadTried: boolean = False;
  CryptoLoadError: string = '';

  p_EVP_MD_CTX_new: function: PEVP_MD_CTX; cdecl;
  p_EVP_MD_CTX_free: procedure(Ctx: PEVP_MD_CTX); cdecl;
  p_EVP_sha256: function: PEVP_MD; cdecl;
  p_EVP_DigestInit_ex: function(Ctx: PEVP_MD_CTX; MD: PEVP_MD;
    Impl: Pointer): LongInt; cdecl;
  p_EVP_DigestUpdate: function(Ctx: PEVP_MD_CTX; Data: Pointer;
    Count: SizeUInt): LongInt; cdecl;
  p_EVP_DigestFinal_ex: function(Ctx: PEVP_MD_CTX; MD: PByte;
    var Size: cardinal): LongInt; cdecl;
  p_HMAC: function(MD: PEVP_MD; Key: Pointer; KeyLen: LongInt;
    Data: PByte; DataLen: SizeUInt; Output: PByte;
    var OutputLen: cardinal): PByte; cdecl;

function ResolveSymbol(const Name: string; out Proc: Pointer): boolean;
begin
  Proc := GetProcedureAddress(CryptoLib, Name);
  Result := Proc <> nil;
  if not Result then
    CryptoLoadError := 'libcrypto does not export ' + Name;
end;

function EnsureCrypto(out ErrMsg: string): boolean;
const
  CANDIDATES: array[0..2] of string = (
    'libcrypto.so.3', 'libcrypto.so.1.1', 'libcrypto.so');
var
  i: integer;
begin
  ErrMsg := '';
  if not CryptoLoadTried then
  begin
    CryptoLoadTried := True;
    CryptoLoadError := 'libcrypto could not be loaded';
    for i := Low(CANDIDATES) to High(CANDIDATES) do
    begin
      CryptoLib := LoadLibrary(CANDIDATES[i]);
      if CryptoLib <> NilHandle then Break;
    end;
    if CryptoLib <> NilHandle then
    begin
      CryptoLoadError := '';
      if not (ResolveSymbol('EVP_MD_CTX_new', Pointer(p_EVP_MD_CTX_new)) and
              ResolveSymbol('EVP_MD_CTX_free', Pointer(p_EVP_MD_CTX_free)) and
              ResolveSymbol('EVP_sha256', Pointer(p_EVP_sha256)) and
              ResolveSymbol('EVP_DigestInit_ex',
                            Pointer(p_EVP_DigestInit_ex)) and
              ResolveSymbol('EVP_DigestUpdate',
                            Pointer(p_EVP_DigestUpdate)) and
              ResolveSymbol('EVP_DigestFinal_ex',
                            Pointer(p_EVP_DigestFinal_ex)) and
              ResolveSymbol('HMAC', Pointer(p_HMAC))) then
      begin
        UnloadLibrary(CryptoLib);
        CryptoLib := NilHandle;
      end;
    end;
  end;
  Result := CryptoLib <> NilHandle;
  if not Result then
    ErrMsg := 'the SHA-256/HMAC backend is unavailable: ' + CryptoLoadError;
end;

function SHA256Stream(Stream: TStream; out Digest: TSHA256Digest;
  out ErrMsg: string): boolean;
const
  CHUNK_SIZE = 64 * 1024;
var
  Ctx: PEVP_MD_CTX;
  Buffer: TBytes;
  Got: LongInt;
  OutLen: cardinal;
begin
  Result := False;
  FillChar(Digest, SizeOf(Digest), 0);
  if not EnsureCrypto(ErrMsg) then Exit;
  if Stream = nil then
  begin
    ErrMsg := 'cannot hash a nil stream';
    Exit;
  end;

  Ctx := p_EVP_MD_CTX_new();
  if Ctx = nil then
  begin
    ErrMsg := 'EVP_MD_CTX_new failed';
    Exit;
  end;
  SetLength(Buffer, CHUNK_SIZE);
  try
    try
      if p_EVP_DigestInit_ex(Ctx, p_EVP_sha256(), nil) <> 1 then
      begin
        ErrMsg := 'EVP_DigestInit_ex failed';
        Exit;
      end;
      repeat
        Got := Stream.Read(Buffer[0], Length(Buffer));
        if Got < 0 then
        begin
          ErrMsg := 'stream returned a negative read length';
          Exit;
        end;
        if Got > 0 then
          if p_EVP_DigestUpdate(Ctx, @Buffer[0], Got) <> 1 then
          begin
            ErrMsg := 'EVP_DigestUpdate failed';
            Exit;
          end;
      until Got = 0;
      OutLen := 0;
      if (p_EVP_DigestFinal_ex(Ctx, @Digest[0], OutLen) <> 1) or
         (OutLen <> SHA256_BYTES) then
      begin
        ErrMsg := 'EVP_DigestFinal_ex failed';
        FillChar(Digest, SizeOf(Digest), 0);
        Exit;
      end;
      Result := True;
    except
      on E: Exception do
      begin
        ErrMsg := 'cannot hash stream: ' + E.Message;
        FillChar(Digest, SizeOf(Digest), 0);
        Result := False;
      end;
    end;
  finally
    p_EVP_MD_CTX_free(Ctx);
    ClearSensitiveBytes(Buffer);
  end;
end;

function SHA256Bytes(const Data: TBytes; out Digest: TSHA256Digest;
  out ErrMsg: string): boolean;
var
  Stream: TBytesStream;
begin
  Stream := TBytesStream.Create(Data);
  try
    Result := SHA256Stream(Stream, Digest, ErrMsg);
  finally
    Stream.Free;
  end;
end;

function SHA256File(const FileName: string; out Digest: TSHA256Digest;
  out ErrMsg: string): boolean;
var
  Stream: TFileStream;
begin
  Result := False;
  FillChar(Digest, SizeOf(Digest), 0);
  ErrMsg := '';
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      Result := SHA256Stream(Stream, Digest, ErrMsg);
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
      ErrMsg := 'cannot hash "' + FileName + '": ' + E.Message;
  end;
end;

function HMACSHA256(const Key, Data: TBytes; out MAC: TSHA256Digest;
  out ErrMsg: string): boolean;
var
  OutLen: cardinal;
  DataPtr: PByte;
begin
  Result := False;
  FillChar(MAC, SizeOf(MAC), 0);
  if Length(Key) < MIN_HMAC_KEY_BYTES then
  begin
    ErrMsg := Format('HMAC key must contain at least %d bytes',
                     [MIN_HMAC_KEY_BYTES]);
    Exit;
  end;
  if not EnsureCrypto(ErrMsg) then Exit;

  if Length(Data) > 0 then DataPtr := @Data[0] else DataPtr := nil;
  OutLen := 0;
  if (p_HMAC(p_EVP_sha256(), @Key[0], Length(Key), DataPtr, Length(Data),
             @MAC[0], OutLen) = nil) or (OutLen <> SHA256_BYTES) then
  begin
    ErrMsg := 'HMAC computation failed';
    FillChar(MAC, SizeOf(MAC), 0);
    Exit;
  end;
  Result := True;
end;

{$ENDIF}

function DigestToHex(const Digest: TSHA256Digest): string;
const
  HEX: array[0..15] of char = '0123456789ABCDEF';
var
  i: integer;
begin
  SetLength(Result, SHA256_HEX_CHARS);
  for i := 0 to High(Digest) do
  begin
    Result[(i * 2) + 1] := HEX[Digest[i] shr 4];
    Result[(i * 2) + 2] := HEX[Digest[i] and $0F];
  end;
end;

function HexNibble(C: char; out Value: byte): boolean;
begin
  Result := True;
  case C of
    '0'..'9': Value := Ord(C) - Ord('0');
    'A'..'F': Value := Ord(C) - Ord('A') + 10;
    'a'..'f': Value := Ord(C) - Ord('a') + 10;
  else
    Value := 0;
    Result := False;
  end;
end;

function HexToBytes(const Hex: string; out Data: TBytes): boolean;
var
  i: integer;
  HiNibble, LoNibble: byte;
begin
  Result := False;
  SetLength(Data, 0);
  if (Length(Hex) and 1) <> 0 then Exit;
  SetLength(Data, Length(Hex) div 2);
  for i := 0 to High(Data) do
  begin
    if not HexNibble(Hex[(i * 2) + 1], HiNibble) then
    begin
      SetLength(Data, 0);
      Exit;
    end;
    if not HexNibble(Hex[(i * 2) + 2], LoNibble) then
    begin
      SetLength(Data, 0);
      Exit;
    end;
    Data[i] := (HiNibble shl 4) or LoNibble;
  end;
  Result := True;
end;

function HexToDigest(const Hex: string; out Digest: TSHA256Digest): boolean;
var
  Data: TBytes;
begin
  FillChar(Digest, SizeOf(Digest), 0);
  Result := (Length(Hex) = SHA256_HEX_CHARS) and HexToBytes(Hex, Data) and
            (Length(Data) = SHA256_BYTES);
  if Result then Move(Data[0], Digest[0], SizeOf(Digest));
  ClearSensitiveBytes(Data);
end;

function BytesToHex(const Data: TBytes): string;
const
  HEX: array[0..15] of char = '0123456789ABCDEF';
var
  i: integer;
begin
  SetLength(Result, Length(Data) * 2);
  for i := 0 to High(Data) do
  begin
    Result[(i * 2) + 1] := HEX[Data[i] shr 4];
    Result[(i * 2) + 2] := HEX[Data[i] and $0F];
  end;
end;

function DigestEqualConstantTime(const A, B: TSHA256Digest): boolean;
var
  i: integer;
  Difference: byte;
begin
  Difference := 0;
  for i := 0 to High(A) do
    Difference := Difference or (A[i] xor B[i]);
  Result := Difference = 0;
end;

procedure ClearSensitiveBytes(var Data: TBytes);
var
  i: integer;
begin
  for i := 0 to High(Data) do Data[i] := 0;
  SetLength(Data, 0);
end;

end.
