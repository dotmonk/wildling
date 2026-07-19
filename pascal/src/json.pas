unit Json;

{$mode objfpc}{$H+}

interface

type
  TJsonType = (jtNull, jtBool, jtNumber, jtString, jtArray, jtObject);

  TJsonValue = class;

  TJsonObjectEntry = record
    Key: string;
    Value: TJsonValue;
  end;

  TJsonValue = class
  public
    ValueType: TJsonType;
    BoolValue: Boolean;
    NumberValue: Double;
    StringValue: string;
    ArrayItems: array of TJsonValue;
    ObjectEntries: array of TJsonObjectEntry;
    destructor Destroy; override;
    function ObjectGet(const Key: string): TJsonValue;
  end;

function JsonParse(const Text: string): TJsonValue;

implementation

uses
  SysUtils;

type
  TParser = class
  private
    FText: string;
    FPos: Integer;
  public
    constructor Create(const AText: string);
    procedure SkipWs;
    function Peek(C: Char): Boolean;
    function Expect(C: Char): Boolean;
    function AtEnd: Boolean;
    function ParseValue: TJsonValue;
    function ParseString: string;
    function ParseNumber: TJsonValue;
    function ParseArray: TJsonValue;
    function ParseObject: TJsonValue;
  end;

destructor TJsonValue.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(ArrayItems) do
    ArrayItems[I].Free;
  for I := 0 to High(ObjectEntries) do
    ObjectEntries[I].Value.Free;
  inherited Destroy;
end;

function TJsonValue.ObjectGet(const Key: string): TJsonValue;
var
  I: Integer;
begin
  for I := 0 to High(ObjectEntries) do
    if ObjectEntries[I].Key = Key then
      Exit(ObjectEntries[I].Value);
  Result := nil;
end;

constructor TParser.Create(const AText: string);
begin
  inherited Create;
  FText := AText;
  FPos := 1;
end;

procedure TParser.SkipWs;
begin
  while (FPos <= Length(FText)) and (FText[FPos] in [' ', #9, #10, #13]) do
    Inc(FPos);
end;

function TParser.Peek(C: Char): Boolean;
begin
  Result := (FPos <= Length(FText)) and (FText[FPos] = C);
end;

function TParser.Expect(C: Char): Boolean;
begin
  SkipWs;
  if not Peek(C) then
    Exit(False);
  Inc(FPos);
  Result := True;
end;

function TParser.AtEnd: Boolean;
begin
  Result := FPos > Length(FText);
end;

function TParser.ParseString: string;
var
  C, Esc: Char;
  Hex: string;
  Code: LongInt;
begin
  Result := '';
  if not Expect('"') then
    raise Exception.Create('Expected string');

  while FPos <= Length(FText) do
  begin
    C := FText[FPos];
    Inc(FPos);
    if C = '"' then
      Exit;
    if C = '\' then
    begin
      if FPos > Length(FText) then
        raise Exception.Create('Unterminated escape');
      Esc := FText[FPos];
      Inc(FPos);
      case Esc of
        '"', '\', '/':
          Result := Result + Esc;
        'b':
          Result := Result + #8;
        'f':
          Result := Result + #12;
        'n':
          Result := Result + #10;
        'r':
          Result := Result + #13;
        't':
          Result := Result + #9;
        'u':
          begin
            if FPos + 3 > Length(FText) then
              raise Exception.Create('Invalid unicode escape');
            Hex := Copy(FText, FPos, 4);
            Inc(FPos, 4);
            Code := StrToInt('$' + Hex);
            Result := Result + Chr(Code and $FF);
          end;
      else
        raise Exception.Create('Invalid escape');
      end;
    end
    else
      Result := Result + C;
  end;
  raise Exception.Create('Unterminated string');
end;

function TParser.ParseNumber: TJsonValue;
var
  StartPos: Integer;
  Raw: string;
  FS: TFormatSettings;
begin
  StartPos := FPos;
  if Peek('-') then
    Inc(FPos);
  while (FPos <= Length(FText)) and (FText[FPos] in ['0'..'9']) do
    Inc(FPos);
  if Peek('.') then
  begin
    Inc(FPos);
    while (FPos <= Length(FText)) and (FText[FPos] in ['0'..'9']) do
      Inc(FPos);
  end;
  if (FPos <= Length(FText)) and (FText[FPos] in ['e', 'E']) then
  begin
    Inc(FPos);
    if Peek('+') or Peek('-') then
      Inc(FPos);
    while (FPos <= Length(FText)) and (FText[FPos] in ['0'..'9']) do
      Inc(FPos);
  end;
  Raw := Copy(FText, StartPos, FPos - StartPos);
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := TJsonValue.Create;
  Result.ValueType := jtNumber;
  Result.NumberValue := StrToFloat(Raw, FS);
end;

function TParser.ParseArray: TJsonValue;
var
  Item: TJsonValue;
begin
  if not Expect('[') then
    raise Exception.Create('Expected [');
  Result := TJsonValue.Create;
  Result.ValueType := jtArray;
  SetLength(Result.ArrayItems, 0);
  SkipWs;
  if Peek(']') then
  begin
    Inc(FPos);
    Exit;
  end;
  while True do
  begin
    Item := ParseValue;
    SetLength(Result.ArrayItems, Length(Result.ArrayItems) + 1);
    Result.ArrayItems[High(Result.ArrayItems)] := Item;
    SkipWs;
    if Peek(']') then
    begin
      Inc(FPos);
      Exit;
    end;
    if not Expect(',') then
    begin
      Result.Free;
      raise Exception.Create('Expected , or ]');
    end;
  end;
end;

function TParser.ParseObject: TJsonValue;
var
  Key: string;
  Value: TJsonValue;
begin
  if not Expect('{') then
    raise Exception.Create('Expected {');
  Result := TJsonValue.Create;
  Result.ValueType := jtObject;
  SetLength(Result.ObjectEntries, 0);
  SkipWs;
  if Peek('}') then
  begin
    Inc(FPos);
    Exit;
  end;
  while True do
  begin
    SkipWs;
    Key := ParseString;
    SkipWs;
    if not Expect(':') then
    begin
      Result.Free;
      raise Exception.Create('Expected :');
    end;
    Value := ParseValue;
    SetLength(Result.ObjectEntries, Length(Result.ObjectEntries) + 1);
    Result.ObjectEntries[High(Result.ObjectEntries)].Key := Key;
    Result.ObjectEntries[High(Result.ObjectEntries)].Value := Value;
    SkipWs;
    if Peek('}') then
    begin
      Inc(FPos);
      Exit;
    end;
    if not Expect(',') then
    begin
      Result.Free;
      raise Exception.Create('Expected , or }');
    end;
  end;
end;

function TParser.ParseValue: TJsonValue;
var
  C: Char;
  S: string;
begin
  SkipWs;
  if FPos > Length(FText) then
    raise Exception.Create('Unexpected end');
  C := FText[FPos];
  if C = '{' then
    Exit(ParseObject);
  if C = '[' then
    Exit(ParseArray);
  if C = '"' then
  begin
    S := ParseString;
    Result := TJsonValue.Create;
    Result.ValueType := jtString;
    Result.StringValue := S;
    Exit;
  end;
  if (C = 't') and (Copy(FText, FPos, 4) = 'true') then
  begin
    Inc(FPos, 4);
    Result := TJsonValue.Create;
    Result.ValueType := jtBool;
    Result.BoolValue := True;
    Exit;
  end;
  if (C = 'f') and (Copy(FText, FPos, 5) = 'false') then
  begin
    Inc(FPos, 5);
    Result := TJsonValue.Create;
    Result.ValueType := jtBool;
    Result.BoolValue := False;
    Exit;
  end;
  if (C = 'n') and (Copy(FText, FPos, 4) = 'null') then
  begin
    Inc(FPos, 4);
    Result := TJsonValue.Create;
    Result.ValueType := jtNull;
    Exit;
  end;
  if (C = '-') or (C in ['0'..'9']) then
    Exit(ParseNumber);
  raise Exception.Create('Invalid JSON value');
end;

function JsonParse(const Text: string): TJsonValue;
var
  Parser: TParser;
begin
  Parser := TParser.Create(Text);
  try
    Result := Parser.ParseValue;
    Parser.SkipWs;
    if not Parser.AtEnd then
    begin
      Result.Free;
      raise Exception.Create('Trailing data');
    end;
  finally
    Parser.Free;
  end;
end;

end.
