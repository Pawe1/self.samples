unit DataBinding.PropertyDecorator;

interface

uses
  System.Classes,   // TComponent
  Lifetime;   // TFreeNotifier

type
  TAccessor<T> = reference to function: T;   // getter
  TMutator<T> = reference to procedure(const AValue: T);   // setter

  IAccessorDecorator<T> = interface   // getter
    ['{2E6ED11B-180F-4474-9CD1-F3EEB9A30572}']
    function GetValue: T;
    property Value: T read GetValue;
  end;

  IMutatorDecorator<T> = interface   // setter
    ['{593F5BE0-237B-42CB-B697-099F16FD8CFF}']
    procedure SetValue(const AValue: T);
    property Value: T write SetValue;
  end;

  IPropertyDecorator<T> = interface
    ['{1706A829-0904-4FB3-BBD4-01E6013EE6C9}']
    function GetValue: T;
    procedure SetValue(const AValue: T);
    property Value: T read GetValue write SetValue;
  end;

  // implementacja dekoratora (aka "Smart Proxy") dla w³aœciwoœci
  TCustomPropertyDecorator<T> = class(TInterfacedObject, IPropertyDecorator<T>)
  private
    FAccessor: TAccessor<T>;
    FMutator: TMutator<T>;
    FValue: T;
    function GetValue: T;
    procedure SetValue(const AValue: T);
  protected
    procedure InvokeAccessor; virtual;
    procedure InvokeMutator; virtual;
  public
    constructor Create(const AAccessor: TAccessor<T>; const AMutator: TMutator<T>); virtual;
  end;

  IComponentTracker = interface
    ['{CFE597DB-8B10-4FA5-B21D-0F76456B21FA}']
    procedure Track(const AComponent: TComponent);
  end;

  // de facto do zastosowañ jako obiekt obserwowany
  TObservable<T> = class(TCustomPropertyDecorator<T>, IComponentTracker)
  private
    FObserver: TComponent;
    FFreeNotifier: TFreeNotifier;
    procedure SetObserver(const AObserver: TComponent);
    procedure IComponentTracker.Track = SetObserver;
  protected
    procedure InvokeAccessor; override;
    procedure InvokeMutator; override;
    procedure HandleFreeNotify(ASender: TObject; AComponent: TComponent); virtual;
    property Observer: TComponent read FObserver write SetObserver;
  public
    constructor Create(const AAccessor: TAccessor<T>; const AMutator: TMutator<T>); override;
    destructor Destroy; override;
  end;

resourcestring   // tutaj z powodu E2506 Method of parameterized type declared in interface section must not use local symbol
  MsgPropertyReadOnlyException = 'Cannot assign to a read-only property';   // = E2129
  MsgPropertyWriteOnlyException = 'Cannot read a write-only property';   // = E2130

implementation

uses
  DataBinding;   // EDataBindingException

constructor TCustomPropertyDecorator<T>.Create(const AAccessor: TAccessor<T>; const AMutator: TMutator<T>);
begin
  FAccessor := AAccessor;
  FMutator := AMutator;
end;

function TCustomPropertyDecorator<T>.GetValue: T;
begin
  InvokeAccessor;
  Result := FValue;
end;

procedure TCustomPropertyDecorator<T>.SetValue(const AValue: T);
begin
  FValue := AValue;
  InvokeMutator;
end;

procedure TCustomPropertyDecorator<T>.InvokeAccessor;
begin
  if Assigned(FAccessor) then
    FValue := FAccessor
  else
    raise EDataBindingException.Create(MsgPropertyWriteOnlyException);
end;

procedure TCustomPropertyDecorator<T>.InvokeMutator;
begin
  if Assigned(FMutator) then
    FMutator(FValue)
  else
    raise EDataBindingException.Create(MsgPropertyReadOnlyException);
end;

constructor TObservable<T>.Create(const AAccessor: TAccessor<T>; const AMutator: TMutator<T>);
begin
  FFreeNotifier := TFreeNotifier.Create(nil);
  FFreeNotifier.OnFreeNotify := HandleFreeNotify;
  inherited;
end;

destructor TObservable<T>.Destroy;
begin
  FFreeNotifier.Free;
  inherited;
end;

procedure TObservable<T>.InvokeAccessor;
begin
  if Assigned(FObserver) then
    inherited;
end;

procedure TObservable<T>.InvokeMutator;
begin
  if Assigned(FObserver) then
    inherited;
end;

procedure TObservable<T>.HandleFreeNotify(ASender: TObject; AComponent: TComponent);
begin
  if AComponent = FObserver then
  begin
    FFreeNotifier.StopObserving(FObserver);
    FObserver := nil;
  end;
end;

procedure TObservable<T>.SetObserver(const AObserver: TComponent);
begin
  if AObserver <> FObserver then
  begin
    FFreeNotifier.StopObserving(FObserver);
    FObserver := AObserver;
    FFreeNotifier.StartObserving(FObserver);
  end;
end;

end.