unit PC.Common.DB.NamedMutex;

interface

uses
  System.SysUtils, System.Classes,
  PC.Data.DB,
  PC.Data.DB.InterfacedDBModule,
  Data.DB, MemDS, DBAccess, Ora;

type
  TPCNamedDBMutex = class(TPCInterfacedDBModule, IDBMutex)
    AcquireProc: TOraStoredProc;
    ReleaseProc: TOraStoredProc;
    procedure PCInterfacedDBModuleDBConnectionChanged(Sender: TObject);
  private
    FName: string;
    FHandle: string;
    procedure CheckHandle;
  protected   // dostępne tylko poprzez interfejs
    procedure Release;
    function TryAcquire: Boolean;
  public
    { Public declarations }
  end;

function NewNamedDBMutex(const ADBConnection: TDBConnection; const AName: string): IDBMutex;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}

{$R *.dfm}

uses
  PC,   // EPCSystemException
  PC.Common.DB.Consts,   // PCDBExceptionCode
  OraError;   // EOraError

resourcestring
  MsgMutexHandleNotAssigned = 'Lock handle not assigned';
  MsgUnableToReleaseMutex = 'Unable to release lock';
  MsgUnableToAcquireMutex = 'Unable to acquire lock';

function NewNamedDBMutex(const ADBConnection: TDBConnection; const AName: string): IDBMutex;
var
  NDBM: TPCNamedDBMutex;
begin
  NDBM := TPCNamedDBMutex.Create(nil);
  NDBM.SetDBConnection(ADBConnection);
  Result := NDBM;
  NDBM.FName := AName;
end;

procedure TPCNamedDBMutex.CheckHandle;
begin
  if FHandle.IsEmpty then
    raise EPCSystemException.Create(MsgMutexHandleNotAssigned);
end;

procedure TPCNamedDBMutex.PCInterfacedDBModuleDBConnectionChanged(Sender: TObject);
begin
  if DBConnection is TCustomDAConnection then
  begin
    AcquireProc.Connection := (DBConnection as TCustomDAConnection);
    ReleaseProc.Connection := (DBConnection as TCustomDAConnection);
  end;
end;

procedure TPCNamedDBMutex.Release;
begin
  CheckHandle;
  with ReleaseProc do
    try
      AutoCommit := False;   // to się kopiuje z sesji
      Params[0].Value := FHandle;
      try
        Execute;
      except
        Exception.RaiseOuterException(EPCSystemException.Create(MsgUnableToReleaseMutex));
      end;
    finally
      FHandle := '';
    end;
end;

function TPCNamedDBMutex.TryAcquire: Boolean;
begin
  Result := True;
  with AcquireProc do
  begin
    Params[1].Value := FName;
    AutoCommit := False;   // to się kopiuje z sesji, a commit kasuje ten rodzaj locka
    try
      Execute;
      FHandle := Params[0].Value;
    except
      on E: EOraError do
      begin
        if E.ErrorCode = PCDBExceptionCode then
          Result := False
        else
          Exception.RaiseOuterException(EPCSystemException.Create(MsgUnableToAcquireMutex));
      end;
      else
        Exception.RaiseOuterException(EPCSystemException.Create(MsgUnableToAcquireMutex));
    end;
  end;
end;

end.