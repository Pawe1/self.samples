unit PC.Collections;

{$I PC.inc}

interface

uses
  System.Classes,
  System.Generics.Collections,   // TObjectList
  System.Generics.Defaults,   // IComparer
  PC.Lifetime;   // TPCFreeNotifier

type

  // hybryda System.Generics.Collections.TObjectList i System.Contnrs.TComponentList
  TComponentList<T: TComponent> = class(TObjectList<T>)
  private
    FDuplicates: TDuplicates;
    FFreeNotifier: TPCFreeNotifier;
  protected
    procedure HandleFreeNotify(ASender: TObject; AComponent: TComponent);   // w przeciwieñstwie do System.Contnrs.TComponentList usuwa wszystkie wyst¹pienia elementu
    procedure Notify(const Value: T; Action: TCollectionNotification); override;
  public
    constructor Create(AOwnsObjects: Boolean = True); overload;
    constructor Create(const AComparer: IComparer<T>; AOwnsObjects: Boolean = True); overload;
    constructor Create(const Collection: TEnumerable<T>; AOwnsObjects: Boolean = True); overload;
    destructor Destroy; override;
    function Add(const Value: T): Integer;
    property Duplicates: TDuplicates read FDuplicates write FDuplicates;
  end;

implementation

uses
  System.Types,   // TDuplicates
  System.RTLConsts;   // SDuplicateItem

{$REGION 'TComponentList'}

function TComponentList<T>.Add(const Value: T): Integer;
begin
  if (Duplicates = TDuplicates.dupAccept) or (IndexOf(Value) = -1) then
    inherited Add(Value)
  else if Duplicates = TDuplicates.dupError then
    raise EListError.CreateFmt(SDuplicateItem, [ItemValue(Value)]);
end;

constructor TComponentList<T>.Create(AOwnsObjects: Boolean);
begin
  inherited;
  FDuplicates := TDuplicates.dupIgnore;
end;

constructor TComponentList<T>.Create(const AComparer: IComparer<T>; AOwnsObjects: Boolean);
begin
  inherited;
  FDuplicates := TDuplicates.dupIgnore;
end;

constructor TComponentList<T>.Create(const Collection: TEnumerable<T>; AOwnsObjects: Boolean);
begin
  inherited;
  FDuplicates := TDuplicates.dupIgnore;
end;

destructor TComponentList<T>.Destroy;
begin
  inherited;
  FFreeNotifier.Free;   // kolejnoœæ jak w System.Generics.Collections.TObjectList
end;

procedure TComponentList<T>.HandleFreeNotify(ASender: TObject; AComponent: TComponent);
var
  Index: Integer;
begin
  Index := IndexOfItem(AComponent, TDirection.FromBeginning);
  while Index <> -1 do
  begin
    Delete(Index);
    Index := IndexOfItem(AComponent, TDirection.FromBeginning);
  end;
end;

procedure TComponentList<T>.Notify(const Value: T; Action: TCollectionNotification);
begin
  if not OwnsObjects then   // dla OwnsObjects w przypadku wielokrotnego wyst¹pienia elementu na liœcie dzia³a³oby tak samo nieprawid³owo, jak System.Contnrs.TComponentList
  begin
    if not Assigned(FFreeNotifier) then
    begin
      FFreeNotifier := TPCFreeNotifier.Create(nil);
      FFreeNotifier.OnFreeNotify := HandleFreeNotify;
    end;

    if Assigned(Value) then
      case Action of
        TCollectionNotification.cnAdded: FFreeNotifier.StartObserving(Value);
        TCollectionNotification.cnExtracted, TCollectionNotification.cnRemoved:
          if IndexOf(Value) = -1 then   // dopiero po usuniêciu wszystkich wyst¹pieñ
            FFreeNotifier.StopObserving(Value);
      end;
  end;
  inherited;
end;

{$ENDREGION}

end.