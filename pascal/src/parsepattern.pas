unit ParsePattern;

{$mode objfpc}{$H+}

interface

uses
  Token;

type
  TStringArray = array of string;

  TDictionaries = class
  private
    FNames: TStringArray;
    FWords: array of TStringArray;
  public
    procedure SetWords(const Name: string; Words: TStringArray);
    function Has(const Name: string): Boolean;
    function Get(const Name: string): TStringArray;
    function Names: TStringArray;
    function Count: Integer;
  end;

  TTokenArray = array of TToken;

function ParsePattern(const InputPattern: string; Dictionaries: TDictionaries): TTokenArray;
function CharsAsVariants(const S: string): TStringArray;

implementation

uses
  SysUtils;

function TDictionaries.Count: Integer;
begin
  Result := Length(FNames);
end;

function TDictionaries.Names: TStringArray;
begin
  Result := FNames;
end;

procedure TDictionaries.SetWords(const Name: string; Words: TStringArray);
var
  I: Integer;
begin
  for I := 0 to High(FNames) do
    if FNames[I] = Name then
    begin
      FWords[I] := Words;
      Exit;
    end;
  SetLength(FNames, Length(FNames) + 1);
  SetLength(FWords, Length(FWords) + 1);
  FNames[High(FNames)] := Name;
  FWords[High(FWords)] := Words;
end;

function TDictionaries.Has(const Name: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FNames) do
    if FNames[I] = Name then
      Exit(True);
end;

function TDictionaries.Get(const Name: string): TStringArray;
var
  I: Integer;
begin
  SetLength(Result, 0);
  for I := 0 to High(FNames) do
    if FNames[I] = Name then
      Exit(FWords[I]);
end;

function CharsAsVariants(const S: string): TStringArray;
var
  I: Integer;
begin
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I - 1] := S[I];
end;

function IsSpecial(C: Char): Boolean;
begin
  Result := Pos(C, '#@$*&?!-%') > 0;
end;

function SplitKeepingDelimiters(const Input: string): TStringArray;
var
  I, J, LiteralStart, Len: Integer;
  C: Char;
  Parts: TStringArray;

  procedure PushPart(const Part: string);
  begin
    if Part = '' then
      Exit;
    SetLength(Parts, Length(Parts) + 1);
    Parts[High(Parts)] := Part;
  end;

begin
  SetLength(Parts, 0);
  if Input = '' then
  begin
    Result := Parts;
    Exit;
  end;

  I := 1;
  LiteralStart := 1;
  Len := Length(Input);

  while I <= Len do
  begin
    C := Input[I];
    if (C = '\') and (I + 1 <= Len) and IsSpecial(Input[I + 1]) then
    begin
      if I > LiteralStart then
        PushPart(Copy(Input, LiteralStart, I - LiteralStart));
      PushPart(Copy(Input, I, 2));
      I := I + 2;
      LiteralStart := I;
    end
    else if IsSpecial(C) and (I + 1 <= Len) and (Input[I + 1] = '{') then
    begin
      if I > LiteralStart then
        PushPart(Copy(Input, LiteralStart, I - LiteralStart));
      J := I + 2;
      while (J <= Len) and (Input[J] <> '}') do
        Inc(J);
      if (J <= Len) and (Input[J] = '}') then
      begin
        PushPart(Copy(Input, I, J - I + 1));
        I := J + 1;
        LiteralStart := I;
      end
      else
      begin
        if I > LiteralStart then
          PushPart(Copy(Input, LiteralStart, I - LiteralStart));
        PushPart(C);
        Inc(I);
        LiteralStart := I;
      end;
    end
    else if IsSpecial(C) then
    begin
      if I > LiteralStart then
        PushPart(Copy(Input, LiteralStart, I - LiteralStart));
      PushPart(C);
      Inc(I);
      LiteralStart := I;
    end
    else
      Inc(I);
  end;

  if LiteralStart <= Len then
    PushPart(Copy(Input, LiteralStart, Len - LiteralStart + 1));

  Result := Parts;
end;

function ParseLengthWithVariants(const Part: string; out StartLength, EndLength: Integer): Boolean;
var
  OpenPos, ClosePos, DashPos: Integer;
  Inner, Left, Right: string;
  S, E, N: Integer;
begin
  StartLength := 1;
  EndLength := 1;
  Result := True;
  OpenPos := Pos('{', Part);
  if OpenPos = 0 then
    Exit;
  ClosePos := Pos('}', Part);
  if (ClosePos = 0) or (ClosePos < OpenPos) then
    Exit;
  Inner := Copy(Part, OpenPos + 1, ClosePos - OpenPos - 1);
  DashPos := Pos('-', Inner);
  if DashPos > 0 then
  begin
    Left := Copy(Inner, 1, DashPos - 1);
    Right := Copy(Inner, DashPos + 1, MaxInt);
    if TryStrToInt(Left, S) and TryStrToInt(Right, E) then
    begin
      StartLength := S;
      EndLength := E;
    end;
  end
  else if TryStrToInt(Inner, N) then
  begin
    StartLength := N;
    EndLength := N;
  end;
end;

function ParseLengthWithString(const Part: string; out Content: string;
  out StartLength, EndLength: Integer): Boolean;
var
  OpenPos, AfterOpen, CloseQuote, I: Integer;
  Rest, AfterQuote, Stripped, Left, Right: string;
  DashPos: Integer;
  S, E, N: Integer;
begin
  Result := False;
  StartLength := 1;
  EndLength := 1;
  Content := '';

  OpenPos := Pos('{''', Part);
  if OpenPos = 0 then
    Exit;

  AfterOpen := OpenPos + 2;
  Rest := Copy(Part, AfterOpen, MaxInt);
  CloseQuote := 0;
  for I := Length(Rest) downto 1 do
    if Rest[I] = '''' then
    begin
      CloseQuote := I;
      Break;
    end;
  if CloseQuote = 0 then
    Exit;

  Content := Copy(Rest, 1, CloseQuote - 1);
  AfterQuote := Copy(Rest, CloseQuote + 1, MaxInt);

  if (Length(AfterQuote) = 0) or ((AfterQuote[1] <> '}') and (AfterQuote[1] <> ',')) then
  begin
    if Pos('}', AfterQuote) = 0 then
      Exit;
  end;

  if (Length(AfterQuote) > 0) and (AfterQuote[1] = ',') then
  begin
    Stripped := Copy(AfterQuote, 2, MaxInt);
    if (Length(Stripped) > 0) and (Stripped[Length(Stripped)] = '}') then
      SetLength(Stripped, Length(Stripped) - 1);
    DashPos := Pos('-', Stripped);
    if DashPos > 0 then
    begin
      Left := Copy(Stripped, 1, DashPos - 1);
      Right := Copy(Stripped, DashPos + 1, MaxInt);
      if TryStrToInt(Left, S) and TryStrToInt(Right, E) then
      begin
        StartLength := S;
        EndLength := E;
      end;
    end
    else if TryStrToInt(Stripped, N) then
    begin
      StartLength := N;
      EndLength := N;
    end;
  end
  else if (Length(AfterQuote) = 0) or (AfterQuote[1] <> '}') then
    Exit;

  Result := True;
end;

function MakeLiteralToken(const Part: string): TToken;
var
  Variants: array[0..0] of string;
begin
  Variants[0] := Part;
  Result := CreateTokenDefaults(Part, Variants);
end;

function SimpleTokenizer(const Part, Alphabet: string): TToken;
var
  StartLength, EndLength: Integer;
  Variants: TStringArray;
begin
  Variants := CharsAsVariants(Alphabet);
  ParseLengthWithVariants(Part, StartLength, EndLength);
  Result := CreateToken(Part, StartLength, EndLength, Variants);
end;

function DictionaryTokenizer(const Part: string; Dictionaries: TDictionaries): TToken;
var
  Content: string;
  StartLength, EndLength: Integer;
  Variants: TStringArray;
begin
  if (not ParseLengthWithString(Part, Content, StartLength, EndLength))
    or ((Content <> '') and (not Dictionaries.Has(Content))) then
    Exit(MakeLiteralToken(Part));

  Variants := Dictionaries.Get(Content);
  Result := CreateToken(Part, StartLength, EndLength, Variants);
end;

function UnescapeCommas(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (I < Length(S)) and (S[I] = '\') and (S[I + 1] = ',') then
    begin
      Result := Result + ',';
      Inc(I, 2);
    end
    else
    begin
      Result := Result + S[I];
      Inc(I);
    end;
  end;
end;

function WordsTokenizer(const Part: string): TToken;
var
  Content, WorkString: string;
  StartLength, EndLength, Index: Integer;
  Variants: TStringArray;
begin
  if not ParseLengthWithString(Part, Content, StartLength, EndLength) then
    Exit(MakeLiteralToken(Part));

  SetLength(Variants, 0);
  WorkString := Content;
  Index := 1;
  while Index <= Length(WorkString) do
  begin
    if (Index < Length(WorkString)) and (WorkString[Index] = '\')
      and (WorkString[Index + 1] = ',') then
      Inc(Index, 2)
    else if WorkString[Index] = ',' then
    begin
      SetLength(Variants, Length(Variants) + 1);
      Variants[High(Variants)] := Copy(WorkString, 1, Index - 1);
      WorkString := Copy(WorkString, Index + 1, MaxInt);
      Index := 1;
    end
    else
      Inc(Index);
  end;
  SetLength(Variants, Length(Variants) + 1);
  Variants[High(Variants)] := WorkString;

  for Index := 0 to High(Variants) do
    Variants[Index] := UnescapeCommas(Variants[Index]);

  Result := CreateToken(Part, StartLength, EndLength, Variants);
end;

function PartToToken(const Part: string; Dictionaries: TDictionaries): TToken;
var
  Variants: array[0..0] of string;
  First: Char;
begin
  if Part = '' then
    Exit(MakeLiteralToken(Part));

  First := Part[1];
  case First of
    '#': Exit(SimpleTokenizer(Part, '0123456789'));
    '@': Exit(SimpleTokenizer(Part, 'abcdefghijklmnopqrstuvwxyz'));
    '*': Exit(SimpleTokenizer(Part, 'abcdefghijklmnopqrstuvwxyz0123456789'));
    '-': Exit(SimpleTokenizer(Part,
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'));
    '!': Exit(SimpleTokenizer(Part, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'));
    '?': Exit(SimpleTokenizer(Part, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'));
    '&': Exit(SimpleTokenizer(Part,
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'));
    '%': Exit(DictionaryTokenizer(Part, Dictionaries));
    '$': Exit(WordsTokenizer(Part));
  end;

  if (Length(Part) > 1) and (Part[1] = '\') and IsSpecial(Part[2]) then
  begin
    Variants[0] := Copy(Part, 2, MaxInt);
    Exit(CreateTokenDefaults(Part, Variants));
  end;

  Result := MakeLiteralToken(Part);
end;

function ParsePattern(const InputPattern: string; Dictionaries: TDictionaries): TTokenArray;
var
  Parts: TStringArray;
  I: Integer;
  Dicts: TDictionaries;
begin
  SetLength(Result, 0);
  if Dictionaries = nil then
  begin
    Dicts := TDictionaries.Create;
    try
      Result := ParsePattern(InputPattern, Dicts);
    finally
      Dicts.Free;
    end;
    Exit;
  end;

  Parts := SplitKeepingDelimiters(InputPattern);
  for I := 0 to High(Parts) do
    if Parts[I] <> '' then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := PartToToken(Parts[I], Dictionaries);
    end;
end;

end.
