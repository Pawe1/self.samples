unit PC.Debug.Dumper;

interface

uses
  System.TypInfo,   // TMemberVisibility
  System.Rtti;

type
  TMemberVisibilities = set of TMemberVisibility;
  TTypeKinds = set of TTypeKind;

  TDumper = class
  private
    FRttiContext: TRttiContext;
    FInstance: Pointer;
    FRttiType: TRttiType;

    FMemberVisibilityFilter: TMemberVisibilities;
    FIgnoredTypeKinds: TTypeKinds;

    FFieldsDump: string;
    FPropertiesDump: string;
    procedure DumpFields;
    procedure DumpProperties;

    function GetResult: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Dump(const AInstance: TObject);
    property MemberVisibilityFilter: TMemberVisibilities write FMemberVisibilityFilter;
    property IgnoredTypeKinds: TTypeKinds write FIgnoredTypeKinds;
    property FieldsDump: string read FFieldsDump;   // => getter
    property PropertiesDump: string read FPropertiesDump;   // => getter
    property Result: string read GetResult;
  end;

implementation

const
  DefaultIgnoredTypeKinds: TTypeKinds = [TTypeKind.tkUnknown{, TTypeKind.tkInterface}];

constructor TDumper.Create;
begin
  inherited;
  FRttiContext := TRttiContext.Create;
  FIgnoredTypeKinds := DefaultIgnoredTypeKinds;
end;

destructor TDumper.Destroy;
begin
  FRttiContext.Free;
  inherited;
end;

procedure TDumper.Clear;
begin
  FInstance := nil;
  FRttiType := nil;
  FFieldsDump := '';
  FPropertiesDump := '';
end;

procedure TDumper.Dump(const AInstance: TObject);
begin
  Clear;

  Assert(Assigned(AInstance));
  FInstance := AInstance;
  FRttiType := FRttiContext.GetType(AInstance.ClassInfo);

  DumpFields;
  DumpProperties;
end;

procedure TDumper.DumpFields;
var
  RttiField: TRttiField;
  FieldDump: string;
begin
  FFieldsDump := '';

  for RttiField in FRttiType.GetFields do
  begin
    if RttiField is TRttiMember then
      if not ((RttiField as TRttiMember).Visibility in FMemberVisibilityFilter) then
        Continue;

    if not Assigned(RttiField.FieldType) then
    begin
      try
        FieldDump := RttiField.ToString + ' : ' + '[unassigned type]';
      except
        // omijane
      end;
      FFieldsDump := FFieldsDump + FieldDump + sLineBreak;
      Continue;
    end;

    if RttiField.FieldType.TypeKind in FIgnoredTypeKinds then
      Continue;

    try
      FieldDump := RttiField.ToString + ': ';
      FieldDump := FieldDump + RttiField.GetValue(FInstance).ToString;
    except
      FieldDump := FieldDump + '[exception]';
    end;

    FFieldsDump := FFieldsDump + FieldDump + sLineBreak;
  end;
end;

procedure TDumper.DumpProperties;
var
  RttiProperty: TRttiProperty;
  PropertyDump: string;
begin
  FPropertiesDump := '';

  for RttiProperty in FRttiType.GetProperties do
  begin
    if RttiProperty is TRttiMember then
      if not ((RttiProperty as TRttiMember).Visibility in FMemberVisibilityFilter) then
        Continue;

    if not Assigned(RttiProperty.PropertyType) then
    begin
      try
        PropertyDump := RttiProperty.ToString + ' : ' + '[unassigned type]';
      except
        // omijane
      end;
      FPropertiesDump := FPropertiesDump + PropertyDump + sLineBreak;
      Continue;
    end;

    if (not RttiProperty.IsReadable) or (RttiProperty.PropertyType.TypeKind in FIgnoredTypeKinds) then
      Continue;

    try
      PropertyDump := RttiProperty.ToString + ': ';
      PropertyDump := PropertyDump + RttiProperty.GetValue(FInstance).ToString;
    except
      PropertyDump := PropertyDump + '[exception]';
    end;
    FPropertiesDump := FPropertiesDump + PropertyDump + sLineBreak;
  end;
end;

function TDumper.GetResult: string;
begin
  Result := FFieldsDump + FPropertiesDump;
end;

end.
