program WildlingCli;

{$mode objfpc}{$H+}

uses
  SysUtils, Token, ParsePattern, Generator, WildlingLib, Json;

const
  FALLBACK_HELP = 'wildling - pattern based string generator' + LineEnding + LineEnding
    + 'Help text unavailable.' + LineEnding;

type
  TRange = record
    StartIdx: Integer;
    EndIdx: Integer;
  end;

  TCliArgs = class
  public
    Selects: array of Integer;
    Ranges: array of TRange;
    Check: Boolean;
    Dictionaries: TDictionaries;
    Patterns: array of string;
    Help: Boolean;
    Version: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure AddSelect(V: Integer);
    procedure AddRange(const R: TRange);
    procedure AddPattern(const P: string);
  end;

constructor TCliArgs.Create;
begin
  inherited Create;
  Dictionaries := TDictionaries.Create;
  SetLength(Selects, 0);
  SetLength(Ranges, 0);
  SetLength(Patterns, 0);
  Check := False;
  Help := False;
  Version := False;
end;

destructor TCliArgs.Destroy;
begin
  Dictionaries.Free;
  inherited Destroy;
end;

procedure TCliArgs.AddSelect(V: Integer);
begin
  SetLength(Selects, Length(Selects) + 1);
  Selects[High(Selects)] := V;
end;

procedure TCliArgs.AddRange(const R: TRange);
begin
  SetLength(Ranges, Length(Ranges) + 1);
  Ranges[High(Ranges)] := R;
end;

procedure TCliArgs.AddPattern(const P: string);
begin
  SetLength(Patterns, Length(Patterns) + 1);
  Patterns[High(Patterns)] := P;
end;

function ParseRange(const Value: string; out R: TRange): Boolean;
var
  Dash: Integer;
  Left, Right: string;
  StartN, EndN: Integer;
  I: Integer;
begin
  Result := False;
  Dash := Pos('-', Value);
  if (Dash <= 1) or (Dash = Length(Value)) then
    Exit;
  Left := Copy(Value, 1, Dash - 1);
  Right := Copy(Value, Dash + 1, MaxInt);
  for I := 1 to Length(Left) do
    if not (Left[I] in ['0'..'9']) then
      Exit;
  for I := 1 to Length(Right) do
    if not (Right[I] in ['0'..'9']) then
      Exit;
  if not TryStrToInt(Left, StartN) then
    Exit;
  if not TryStrToInt(Right, EndN) then
    Exit;
  if StartN > EndN then
    Exit;
  R.StartIdx := StartN;
  R.EndIdx := EndN;
  Result := True;
end;

function ReadFileRaw(const Path: string): string;
var
  F: File;
  Size: Int64;
begin
  AssignFile(F, Path);
  Reset(F, 1);
  try
    Size := FileSize(F);
    SetLength(Result, Size);
    if Size > 0 then
      BlockRead(F, Result[1], Size);
  finally
    CloseFile(F);
  end;
end;

function LoadDictionaryFile(const Path: string): TStringArray;
var
  Raw, Line: string;
  I: Integer;

  procedure PushLine(const S: string);
  var
    T: string;
  begin
    T := Trim(S);
    if T = '' then
      Exit;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := T;
  end;

begin
  SetLength(Result, 0);
  Raw := ReadFileRaw(Path);
  Line := '';
  I := 1;
  while I <= Length(Raw) do
  begin
    if Raw[I] = #13 then
    begin
      PushLine(Line);
      Line := '';
      if (I < Length(Raw)) and (Raw[I + 1] = #10) then
        Inc(I);
    end
    else if Raw[I] = #10 then
    begin
      PushLine(Line);
      Line := '';
    end
    else
      Line := Line + Raw[I];
    Inc(I);
  end;
  if Line <> '' then
    PushLine(Line);
end;

procedure ApplyDictionaryPath(Args: TCliArgs; const Name, Path: string);
var
  Words: TStringArray;
begin
  if not FileExists(Path) then
    Exit;
  try
    Words := LoadDictionaryFile(Path);
    Args.Dictionaries.SetWords(Name, Words);
  except
  end;
end;

procedure ApplyDictionaryJson(Args: TCliArgs; const Name: string; Value: TJsonValue);
var
  I: Integer;
  Words: TStringArray;
  Item: TJsonValue;
begin
  if Value.ValueType = jtArray then
  begin
    SetLength(Words, 0);
    for I := 0 to High(Value.ArrayItems) do
    begin
      Item := Value.ArrayItems[I];
      SetLength(Words, Length(Words) + 1);
      case Item.ValueType of
        jtString:
          Words[High(Words)] := Item.StringValue;
        jtNumber:
          Words[High(Words)] := IntToStr(Trunc(Item.NumberValue));
        jtBool:
          if Item.BoolValue then
            Words[High(Words)] := 'true'
          else
            Words[High(Words)] := 'false';
      else
        SetLength(Words, Length(Words) - 1);
      end;
    end;
    Args.Dictionaries.SetWords(Name, Words);
  end
  else if Value.ValueType = jtString then
    ApplyDictionaryPath(Args, Name, Value.StringValue);
end;

procedure ApplyTemplate(Args: TCliArgs; const Path: string);
var
  Raw: string;
  Root, Node, Val, Dicts: TJsonValue;
  I: Integer;
  Number: Integer;
  R: TRange;
  Ok: Boolean;
begin
  if not FileExists(Path) then
  begin
    WriteLn(StdErr, 'Template file not found: ', Path);
    Halt(1);
  end;
  Ok := False;
  Root := nil;
  try
    Raw := ReadFileRaw(Path);
    Root := JsonParse(Raw);
    Ok := True;
  except
    Ok := False;
  end;
  if (not Ok) or (Root = nil) or (Root.ValueType <> jtObject) then
  begin
    if Root <> nil then
      Root.Free;
    WriteLn(StdErr, 'Invalid JSON template: ', Path);
    Halt(1);
  end;
  try
    Node := Root.ObjectGet('check');
    if (Node <> nil) and (Node.ValueType = jtBool) and Node.BoolValue then
      Args.Check := True;

    Node := Root.ObjectGet('select');
    if (Node <> nil) and (Node.ValueType = jtArray) then
      for I := 0 to High(Node.ArrayItems) do
      begin
        Val := Node.ArrayItems[I];
        Number := -1;
        if Val.ValueType = jtNumber then
          Number := Trunc(Val.NumberValue)
        else if Val.ValueType = jtString then
          TryStrToInt(Val.StringValue, Number);
        if Number >= 0 then
          Args.AddSelect(Number);
      end;

    Node := Root.ObjectGet('range');
    if (Node <> nil) and (Node.ValueType = jtArray) then
      for I := 0 to High(Node.ArrayItems) do
      begin
        Val := Node.ArrayItems[I];
        if Val.ValueType = jtString then
          if ParseRange(Val.StringValue, R) then
            Args.AddRange(R);
      end;

    Dicts := Root.ObjectGet('dictionaries');
    if (Dicts <> nil) and (Dicts.ValueType = jtObject) then
      for I := 0 to High(Dicts.ObjectEntries) do
        ApplyDictionaryJson(Args, Dicts.ObjectEntries[I].Key, Dicts.ObjectEntries[I].Value);

    Node := Root.ObjectGet('patterns');
    if (Node <> nil) and (Node.ValueType = jtArray) then
      for I := 0 to High(Node.ArrayItems) do
      begin
        Val := Node.ArrayItems[I];
        if Val.ValueType = jtString then
          Args.AddPattern(Val.StringValue);
      end;
  finally
    Root.Free;
  end;
end;

function ParseArgs: TCliArgs;
var
  I: Integer;
  Arg, Spec, Name, Path: string;
  Colon: Integer;
  Val: Integer;
  R: TRange;
begin
  Result := TCliArgs.Create;
  I := 1;
  while I <= ParamCount do
  begin
    Arg := ParamStr(I);
    if (Arg = '--help') or (Arg = '-h') then
    begin
      Result.Help := True;
      Inc(I);
    end
    else if (Arg = '--version') or (Arg = '-v') then
    begin
      Result.Version := True;
      Inc(I);
    end
    else if Arg = '--check' then
    begin
      Result.Check := True;
      Inc(I);
    end
    else if Arg = '--select' then
    begin
      Inc(I);
      if I > ParamCount then
        Break;
      if TryStrToInt(ParamStr(I), Val) and (Val >= 0) then
        Result.AddSelect(Val);
      Inc(I);
    end
    else if Arg = '--range' then
    begin
      Inc(I);
      if I > ParamCount then
        Break;
      if ParseRange(ParamStr(I), R) then
        Result.AddRange(R);
      Inc(I);
    end
    else if Arg = '--dictionary' then
    begin
      Inc(I);
      if I > ParamCount then
        Break;
      Spec := ParamStr(I);
      Colon := Pos(':', Spec);
      if (Colon > 1) and (Colon < Length(Spec)) then
      begin
        Name := Copy(Spec, 1, Colon - 1);
        Path := Copy(Spec, Colon + 1, MaxInt);
        ApplyDictionaryPath(Result, Name, Path);
      end;
      Inc(I);
    end
    else if Arg = '--template' then
    begin
      Inc(I);
      if I > ParamCount then
      begin
        WriteLn(StdErr, 'Missing path for --template');
        Result.Free;
        Halt(1);
      end;
      ApplyTemplate(Result, ParamStr(I));
      Inc(I);
    end
    else
    begin
      Result.AddPattern(Arg);
      Inc(I);
    end;
  end;
end;

function LoadHelpText: string;
var
  ExeDir: string;
  Candidates: array[0..2] of string;
  I: Integer;
begin
  ExeDir := ExtractFilePath(ExpandFileName(ParamStr(0)));
  Candidates[0] := ExeDir + 'help.txt';
  Candidates[1] := ExeDir + '..' + PathDelim + 'docs' + PathDelim + 'help.txt';
  Candidates[2] := 'docs' + PathDelim + 'help.txt';
  for I := 0 to High(Candidates) do
    if FileExists(Candidates[I]) then
    begin
      Result := ReadFileRaw(Candidates[I]);
      while (Length(Result) > 0) and (Result[Length(Result)] in [#10, #13, ' ', #9]) do
        SetLength(Result, Length(Result) - 1);
      Exit;
    end;
  Result := TrimRight(FALLBACK_HELP);
end;

function FormatList(const Values: array of string): string;
var
  I: Integer;
begin
  if Length(Values) = 0 then
    Exit('');
  Result := ' ';
  for I := 0 to High(Values) do
  begin
    if I > 0 then
      Result := Result + ' ';
    Result := Result + Values[I];
  end;
end;

procedure PrintCheck(Args: TCliArgs; W: TWildling);
var
  DictNames, SelectStrs, RangeStrs: array of string;
  I: Integer;
  Gens: TGeneratorArray;
begin
  DictNames := Args.Dictionaries.Names;
  SetLength(SelectStrs, Length(Args.Selects));
  for I := 0 to High(Args.Selects) do
    SelectStrs[I] := IntToStr(Args.Selects[I]);
  SetLength(RangeStrs, Length(Args.Ranges));
  for I := 0 to High(Args.Ranges) do
    RangeStrs[I] := IntToStr(Args.Ranges[I].StartIdx) + '-' + IntToStr(Args.Ranges[I].EndIdx);

  WriteLn('patterns:', FormatList(Args.Patterns));
  WriteLn('dictionaries:', FormatList(DictNames));
  WriteLn('select:', FormatList(SelectStrs));
  WriteLn('range:', FormatList(RangeStrs));
  Write('total: ', W.Count);
  Gens := W.Generators;
  for I := 0 to High(Gens) do
    Write(LineEnding, 'generator: ', Gens[I].Source, ' ', Gens[I].Count);
  WriteLn;
end;

procedure PrintValueOrOor(W: TWildling; Index: Int64; var Oor: Boolean);
var
  Value: string;
begin
  if W.Get(Index, Value) then
    WriteLn(Value)
  else
  begin
    WriteLn(StdErr, 'out of range: ', Index);
    Oor := True;
  end;
end;

var
  Args: TCliArgs;
  W: TWildling;
  Value: string;
  I, J: Integer;
  ExitCode: Integer;
  Oor: Boolean;
begin
  ExitCode := 0;
  Args := ParseArgs;
  try
    if Args.Help then
    begin
      WriteLn(LoadHelpText);
      ExitCode := 0;
      Exit;
    end;

    if Args.Version then
    begin
      WriteLn('wildling ', WILDLING_VERSION);
      ExitCode := 0;
      Exit;
    end;

    if Length(Args.Patterns) = 0 then
    begin
      WriteLn(StdErr, 'No pattern provided. Use --help for usage information.');
      ExitCode := 1;
      Exit;
    end;

    W := CreateWildling(Args.Patterns, Args.Dictionaries);
    try
      if Args.Check then
        PrintCheck(Args, W)
      else if (Length(Args.Selects) > 0) or (Length(Args.Ranges) > 0) then
      begin
        Oor := False;
        for I := 0 to High(Args.Selects) do
          PrintValueOrOor(W, Args.Selects[I], Oor);
        for I := 0 to High(Args.Ranges) do
          for J := Args.Ranges[I].StartIdx to Args.Ranges[I].EndIdx do
            PrintValueOrOor(W, J, Oor);
        if Oor then
          ExitCode := 1;
      end
      else
        while W.Next(Value) do
          WriteLn(Value);
    finally
      W.Free;
    end;
  finally
    Args.Free;
  end;
  if ExitCode <> 0 then
    Halt(ExitCode);
end.
