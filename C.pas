unit PC.DesignPatterns.SmartObserver;

interface

uses
  System.Generics.Collections,
  System.Generics.Defaults,   // TSingletonImplementation
  PC.Lifetime,
  PC.DesignPatterns.Observer;

type

  // przeznaczone do przyspieszenia rzutowania referencji interfejsowej na obiekt
  IInstanceReference = interface   { TODO -opc -cdev : Przenieść dwa piętra wyżej? }
    ['{9A62DD16-D29B-4881-AE86-11D6565F346B}']
    function GetInstance: TObject;
  end;

  // ręczne wywołanie AddObserver dodaje obserwację czasu życia tylko z jednej strony!
  TSmartObservable<TValue> = class(TObservable<TValue>, IFreeNotificationObserver, IInstanceReference)
  private
    procedure FreeNotification(AObject: TObject);
    procedure SendFreeNotification; inline;
  protected
    function GetInstance: TObject;
  public
    destructor Destroy; override;
  end;

  // Powiadomienie jest wysyłane jeśli obserwowany obiekt implementuje IFreeNotificationObserver
  TSmartSinlgeObserver<TValue> = class(TSingletonImplementation, IObserver<TValue>, IFreeNotificationObserver, IInstanceReference)
  private
    FObservable: Pointer;   // Dla Delphi 10.1+ można próbować użyć [Weak]
    function GetObservable: IObservable<TValue>;
    procedure SetObservable(const AObservable: IObservable<TValue>);   // Dla Delphi 10.1+ można próbować użyć [Weak]

    procedure FreeNotification(AObject: TObject);
    procedure SendFreeNotification; inline;
  protected
    function GetInstance: TObject;
    procedure Update(const AObservable: TValue); virtual;
  public
    destructor Destroy; override;
    property Observable: IObservable<TValue> read GetObservable write SetObservable;   // Dla Delphi 10.1+ można próbować użyć [Weak]
  end;

  // Powiadomienie jest wysyłane jeśli obserwowany obiekt implementuje IFreeNotificationObserver
  TSmartMultiObserver<TValue> = class(TSingletonImplementation, IObserver<TValue>, IFreeNotificationObserver, IInstanceReference)
  private
    FObservables: TList<Pointer>;   // Dla Delphi 10.1+ można próbować użyć [Weak]

    procedure FreeNotification(AObject: TObject);
    procedure SendFreeNotification; inline;
    function GetObservables: TList<Pointer>;   // Dla Delphi 10.1+ można próbować użyć [Weak]
  protected
    function GetInstance: TObject;
    procedure Update(const AObservable: TValue); virtual;
    property Observables: TList<Pointer> read GetObservables;   // Dla Delphi 10.1+ można próbować użyć [Weak]
  public
    destructor Destroy; override;
    procedure AddObservable(const AObservable: IObservable<TValue>);
    procedure RemoveObservable(const AObservable: IObservable<TValue>);
  end;

implementation

uses
  System.SysUtils;

destructor TSmartObservable<TValue>.Destroy;
begin
  SendFreeNotification;
  inherited;
end;

procedure TSmartObservable<TValue>.FreeNotification(AObject: TObject);
var
  Observer: Pointer;
  InstanceReference: IInstanceReference;
begin
  for Observer in Observers do
    if Supports(IObserver<TValue>(Observer), IInstanceReference, InstanceReference) then
      if AObject = InstanceReference.GetInstance then
      begin
        Observers.Remove(Observer);
        Break;
      end;
end;

function TSmartObservable<TValue>.GetInstance: TObject;
begin
  Result := Self;
end;

procedure TSmartObservable<TValue>.SendFreeNotification;
var
  Observer: Pointer;
  FreeNotificationObserver: IFreeNotificationObserver;
begin
  for Observer in Observers do
    if Supports(IObserver<TValue>(Observer), IFreeNotificationObserver, FreeNotificationObserver) then
      FreeNotificationObserver.FreeNotification(Self);
end;

destructor TSmartSinlgeObserver<TValue>.Destroy;
begin
  SendFreeNotification;
  inherited;
end;

procedure TSmartSinlgeObserver<TValue>.FreeNotification(AObject: TObject);
var
  InstanceReference: IInstanceReference;
begin
  if Assigned(FObservable) then
    if Supports(IObservable<TValue>(FObservable), IInstanceReference, InstanceReference) then
      if AObject = InstanceReference.GetInstance then
        FObservable := nil;
end;

function TSmartSinlgeObserver<TValue>.GetInstance: TObject;
begin
  Result := Self;
end;

function TSmartSinlgeObserver<TValue>.GetObservable: IObservable<TValue>;
begin
  if Assigned(FObservable) then
    Result := IObservable<TValue>(FObservable)
  else
    Result := nil;
end;

procedure TSmartSinlgeObserver<TValue>.SendFreeNotification;
var
  FreeNotificationObserver: IFreeNotificationObserver;
begin
  if Assigned(FObservable) then
    if Supports(IObservable<TValue>(FObservable), IFreeNotificationObserver, FreeNotificationObserver) then
      FreeNotificationObserver.FreeNotification(Self);
end;

procedure TSmartSinlgeObserver<TValue>.SetObservable(const AObservable: IObservable<TValue>);
begin
  if FObservable <> Pointer(AObservable) then
  begin
    if Assigned(FObservable) then
      IObservable<TValue>(FObservable).RemoveObserver(Self);

    FObservable := Pointer(AObservable);

    if Assigned(FObservable) then
      IObservable<TValue>(FObservable).AddObserver(Self);
  end;
end;

procedure TSmartSinlgeObserver<TValue>.Update(const AObservable: TValue);
begin
end;

procedure TSmartMultiObserver<TValue>.AddObservable(const AObservable: IObservable<TValue>);
begin
  Assert(Assigned(AObservable));
  if not Observables.Contains(Pointer(AObservable)) then
    Observables.Add(Pointer(AObservable));
end;

destructor TSmartMultiObserver<TValue>.Destroy;
begin
  SendFreeNotification;
  inherited;
end;

procedure TSmartMultiObserver<TValue>.FreeNotification(AObject: TObject);
var
  Observable: Pointer;
  InstanceReference: IInstanceReference;
begin
  if Assigned(FObservables) then
    for Observable in FObservables do
      if Supports(IObservable<TValue>(Observable), IInstanceReference, InstanceReference) then
        if AObject = InstanceReference.GetInstance then
        begin
          FObservables.Remove(Observable);
          Break;
        end;
end;

function TSmartMultiObserver<TValue>.GetInstance: TObject;
begin
  Result := Self;
end;

function TSmartMultiObserver<TValue>.GetObservables: TList<Pointer>;
begin
  if not Assigned(FObservables) then
    FObservables := TList<Pointer>.Create;
  Result := FObservables;
end;

procedure TSmartMultiObserver<TValue>.RemoveObservable(const AObservable: IObservable<TValue>);
begin
  Assert(Assigned(AObservable));
  if Assigned(FObservables) then
    if Observables.Contains(Pointer(AObservable)) then
      Observables.Remove(Pointer(AObservable));
end;

procedure TSmartMultiObserver<TValue>.SendFreeNotification;
var
  Observable: Pointer;
  FreeNotificationObserver: IFreeNotificationObserver;
begin
  if Assigned(FObservables) then
    for Observable in Observables do
      if Supports(IObservable<TValue>(Observable), IFreeNotificationObserver, FreeNotificationObserver) then
        FreeNotificationObserver.FreeNotification(Self);
end;

procedure TSmartMultiObserver<TValue>.Update(const AObservable: TValue);
begin
end;

end.