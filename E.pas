unit PC.Navigation.ActionNavigator;

interface

uses
  System.Classes,   // TBasicAction
  System.Generics.Collections,   // TCollectionNotifyEvent, TCollectionNotification
  PC.Lifetime,   // TPCFreeNotifier
  PC.Collections,   // TComponentList
  PC.Navigation;

type
  TNavigationCommand = TBasicAction;

  IBasicActionNavigation = IBasicNavigation<TNavigationCommand>;
  IBasicActionTwoWayNavigation = IBasicTwoWayNavigation<TNavigationCommand>;

  TPCCustomBasicActionNavigator = class(TComponent)
  private
    FAllowGoBack: Boolean;

    { TODO -opc -cdev : funckcje zwracające stany stosów, numer pozycjy w stosunku do całości (uwzględniając wizarda / czy można skakać do przodu? }

    FBackStack: TComponentList<TNavigationCommand>;
    FCurrentCommand: TNavigationCommand;
    FForwardStack: TComponentList<TNavigationCommand>;
    FFreeNotifier: TPCFreeNotifier;

    procedure CheckCanScroll(const AVector: Integer);
    function CanScroll(const AVector: Integer): Boolean;
    procedure Scroll(const AVector: Integer);   // przewiniecie stosow
    function GetCommandByVector(const AVector: Integer): TNavigationCommand;

    procedure InvokeCurrentCommand;
    procedure SetCurrentCommand(const ACommand: TNavigationCommand);
  protected
    procedure CheckCurrentCommand;
    procedure DoNavigated; virtual;
    procedure HandleFreeNotify(ASender: TObject; AComponent: TComponent); virtual;

    procedure GoToBeginning;
    function CanGoBack: Boolean;
    procedure GoBack;
    procedure GoBy(const AVector: Integer);   // x steps
    function CanGoForward: Boolean;
    procedure GoForward;
    procedure GoToEnd;
    function CanNavigate(const ATarget: TNavigationCommand): Boolean;
    procedure Navigate(const ACommand: TNavigationCommand); virtual;

    function TestDump: string; virtual;

    property AllowGoBack: Boolean read FAllowGoBack write FAllowGoBack;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

uses
  System.SysUtils;   // Exception

resourcestring
  MsgCurrentCommandNotAssigned = 'Current command is not assigned';
  MsgCommandNotAssigned = 'Command is not assigned';
  MsgCannotScroll = 'Cannot scroll command journal entries by vector [%d]';

constructor TPCCustomBasicActionNavigator.Create(AOwner: TComponent);
begin
  FAllowGoBack := True;
  FBackStack := TComponentList<TNavigationCommand>.Create(False);
  FForwardStack := TComponentList<TNavigationCommand>.Create(False);
  inherited;   // ta kolejność daje możliwość korzystania w OnCreate
  FFreeNotifier := TPCFreeNotifier.Create(nil);
  FFreeNotifier.OnFreeNotify := HandleFreeNotify;
end;

destructor TPCCustomBasicActionNavigator.Destroy;
begin
  FFreeNotifier.Free;
  FBackStack.Free;
  FForwardStack.Free;
  inherited;
end;

function TPCCustomBasicActionNavigator.GetCommandByVector(const AVector: Integer): TNavigationCommand;
begin
  Result := nil;
  if AVector < 0 then
  begin
    if FBackStack.Count >= (- AVector) then
      Result := FBackStack[FBackStack.Count + AVector];
  end
  else if AVector > 0 then
  begin
    if FForwardStack.Count >= AVector then
      Result := FForwardStack[FForwardStack.Count - AVector];
  end
  else   // AVector = 0
    Result := FCurrentCommand;
end;

procedure TPCCustomBasicActionNavigator.HandleFreeNotify(ASender: TObject; AComponent: TComponent);
begin
  if AComponent = FCurrentCommand then
    FCurrentCommand := nil;
end;

procedure TPCCustomBasicActionNavigator.SetCurrentCommand(const ACommand: TNavigationCommand);
begin
  if not Assigned(ACommand) then
    raise EPCNavigationException.Create(MsgCommandNotAssigned);

  FFreeNotifier.StopObserving(FCurrentCommand);   // zabezpieczone
  FCurrentCommand := ACommand;
  FFreeNotifier.StartObserving(FCurrentCommand);   // zabezpieczone
end;

procedure TPCCustomBasicActionNavigator.InvokeCurrentCommand;
begin
  CheckCurrentCommand;

  TestDump;   // testowo

  FCurrentCommand.Execute;
end;

// ####################

procedure TPCCustomBasicActionNavigator.CheckCurrentCommand;
begin
  if not Assigned(FCurrentCommand) then
    raise EPCNavigationException.Create(MsgCurrentCommandNotAssigned)
end;

procedure TPCCustomBasicActionNavigator.CheckCanScroll(const AVector: Integer);
begin
  try
    CheckCurrentCommand;
  except
    { TODO -opc -cdev : sprawdzić }

    Exception.RaiseOuterException(EPCNavigationException.CreateFmt(MsgCannotScroll, [AVector]));
  end;
  if not CanScroll(AVector) then
    raise EPCNavigationException.CreateFmt(MsgCannotScroll, [AVector])
end;

function TPCCustomBasicActionNavigator.CanScroll(const AVector: Integer): Boolean;
begin
  if not Assigned(FCurrentCommand) then
    Result := False
  else if AVector < 0 then
    Result := FAllowGoBack and (FBackStack.Count >= (- AVector))
  else if AVector > 0 then
    Result := FForwardStack.Count >= AVector;
  else   // AVector = 0
    Result := True
end;

procedure TPCCustomBasicActionNavigator.Scroll(const AVector: Integer);
var
  Target: TNavigationCommand;
  LC: Integer;
begin
  if AVector = 0 then
    Exit;

  CheckCanScroll(AVector);
  Target := GetCommandByVector(AVector);

  if AVector < 0 then
  begin
    FForwardStack.Add(FCurrentCommand);
    for LC := (- AVector) - 2 downto 0 do   // kopiowanie nie obejmuje Targeta
    begin
      FForwardStack.Add(FBackStack.Last);
      FBackStack.Delete(FBackStack.Count - 1);
    end;
    FBackStack.Delete(FBackStack.Count - 1);   // czyli Target
  end
  else if AVector > 0 then
  begin
    FBackStack.Add(FCurrentCommand);
    for LC := AVector - 2 downto 0 do   // kopiowanie nie obejmuje Targeta
    begin
      FBackStack.Add(FForwardStack.Last);
      FForwardStack.Delete(FForwardStack.Count - 1);
    end;
    FForwardStack.Delete(FForwardStack.Count - 1);   // czyli Target
  end;

  SetCurrentCommand(Target);
end;

// ####################

procedure TPCCustomBasicActionNavigator.DoNavigated;
begin
end;

procedure TPCCustomBasicActionNavigator.GoToBeginning;
begin
  GoBy(- FBackStack.Count);
end;

function TPCCustomBasicActionNavigator.CanGoBack: Boolean;
begin
  Result := CanScroll(-1);
end;

procedure TPCCustomBasicActionNavigator.GoBack;
begin
  GoBy(-1);
end;

procedure TPCCustomBasicActionNavigator.GoBy(const AVector: Integer);
begin
  Scroll(AVector);
  InvokeCurrentCommand;   // ponowna kontrola
end;

function TPCCustomBasicActionNavigator.CanNavigate(const ATarget: TNavigationCommand): Boolean;
begin
  Result := True;   { TODO -opc -cdev : do zrobienia }
end;

function TPCCustomBasicActionNavigator.CanGoForward: Boolean;
begin
  Result := CanScroll(1);
end;

procedure TPCCustomBasicActionNavigator.GoForward;
begin
  GoBy(1);
end;

procedure TPCCustomBasicActionNavigator.GoToEnd;
begin
  GoBy(FForwardStack.Count);
end;

procedure TPCCustomBasicActionNavigator.Navigate(const ACommand: TNavigationCommand);
begin
  if not Assigned(ACommand) then
    Exit;

  if ACommand = FCurrentCommand then
    Exit;

  if Assigned(FCurrentCommand) then
    FBackStack.Add(FCurrentCommand);
  FForwardStack.Clear;
  SetCurrentCommand(ACommand);
  InvokeCurrentCommand;
end;

function TPCCustomBasicActionNavigator.TestDump: string;
var
  LC: Integer;
  Cmd: TNavigationCommand;
  PL: string;
begin
  Result := '';

  for LC := 0 to FBackStack.Count - 1 do
  begin
    Cmd := FBackStack[LC];
    Result := Result + Cmd.Name + ' ';
  end;

  if Assigned(FCurrentCommand) then
    Result := Result + '[' + FCurrentCommand.Name + '] '
  else
    Result := Result + '[ - ] ';

  for LC := FForwardStack.Count - 1 downto 0 do
  begin
    Cmd := FForwardStack[LC];
    Result := Result + Cmd.Name + ' ';
  end;
end;

end.