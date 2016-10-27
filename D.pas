unit PC.Windows.MemoryMapping;

interface

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF MSWINDOWS}
  PC.Windows.RemoteDesktopServices;

{$IFDEF MSWINDOWS}
type
  TFileMapping = class
  private
    FName: string;
    FHandle: THandle;
    FDataSize: Integer;
    FExisted: Boolean;
    FData: Pointer;
  public
    constructor Create(const ANamespace: TKernelObjectNamespace; const AName: string; const AMaxSize: DWORD);
    destructor Destroy; override;
    property Data: Pointer read FData;
    property Existed: Boolean read FExisted;
  end;

  TMappedValue<T> = class
  private
    type
      PValue = ^T;
  private
    FSize: Integer;
    FMapping: TFileMapping;
    function GetExisted: Boolean;
    function GetValue: T;
    procedure SetValue(const AValue: T);
    function GetValuePointer: PValue;
  protected
    property ValuePointer: PValue read GetValuePointer;
  public
    constructor Create(const ANamespace: TKernelObjectNamespace; const AMappingName: string);
    destructor Destroy; override;
    property Existed: Boolean read GetExisted;
    property Value: T read GetValue write SetValue;
  end;
{$ENDIF MSWINDOWS}

implementation

uses
  System.SysUtils,
  PC.Windows.Security;

{$IFDEF MSWINDOWS}
constructor TFileMapping.Create(const ANamespace: TKernelObjectNamespace; const AName: string; const AMaxSize: DWORD);
begin
  inherited Create;
  FName := ANamespace.Prefix + StringReplace(AName, '\', '', [rfReplaceAll]);
  if ANamespace = TKernelObjectNamespace.Global then
    with TProcessTokenPrivilegeEditor.Create(GetCurrentProcess) do
    try
      EnablePrivilege('SeCreateGlobalPrivilege');
    finally
      Free;
    end;

  FHandle := CreateFileMapping(INVALID_HANDLE_VALUE,   // przez plik stronicowania
    nil,
    PAGE_READWRITE,{PAGE_READONLY}
    0, AMaxSize, PChar(FName));

  if FHandle = 0 then
    RaiseLastOSError;

  FExisted := GetLastError = ERROR_ALREADY_EXISTS;

  FData := MapViewOfFile(FHandle,
    SECTION_MAP_READ or SECTION_MAP_WRITE,   // R/W
    0,
    0,
    FDataSize);

  if FData = nil then
  begin
    CloseHandle(FHandle);
    FHandle := INVALID_HANDLE_VALUE;
  end;
end;

destructor TFileMapping.Destroy;
begin
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    UnmapViewOfFile(FData);
    CloseHandle(FHandle);
  end;
  inherited;
end;

constructor TMappedValue<T>.Create(const ANamespace: TKernelObjectNamespace; const AMappingName: string);
begin
  inherited Create;
  FSize := SizeOf(T);
  FMapping := TFileMapping.Create(ANamespace, AMappingName, FSize);
end;

destructor TMappedValue<T>.Destroy;
begin
  FMapping.Free;
  inherited;
end;

function TMappedValue<T>.GetExisted: Boolean;
begin
  Result := False;
  if Assigned(FMapping) then
    Result := FMapping.Existed;
end;

function TMappedValue<T>.GetValuePointer: PValue;
begin
  Result := PValue(FMapping.Data^);
end;

function TMappedValue<T>.GetValue: T;
begin
  Result := T(FMapping.Data^);
end;

procedure TMappedValue<T>.SetValue(const AValue: T);
begin
  T(FMapping.Data^) := AValue;
end;
{$ENDIF MSWINDOWS}

end.