unit Token;

{$mode objfpc}{$H+}

interface

type
  TToken = class
  private
    FSrc: string;
    FStartLength: Integer;
    FEndLength: Integer;
    FVariants: array of string;
    FCount: Int64;
  public
    constructor Create(const ASrc: string; AStartLength, AEndLength: Integer;
      const AVariants: array of string);
    function Count: Int64;
    function Src: string;
    function Get(Index: Int64): string;
  end;

function IntPow(Base: Int64; Exp: Integer): Int64;
function CreateToken(const ASrc: string; AStartLength, AEndLength: Integer;
  const AVariants: array of string): TToken;
function CreateTokenDefaults(const ASrc: string; const AVariants: array of string): TToken;

implementation

function IntPow(Base: Int64; Exp: Integer): Int64;
var
  I: Integer;
begin
  Result := 1;
  for I := 0 to Exp - 1 do
    Result := Result * Base;
end;

constructor TToken.Create(const ASrc: string; AStartLength, AEndLength: Integer;
  const AVariants: array of string);
var
  LengthVal, I: Integer;
begin
  inherited Create;
  FSrc := ASrc;
  if AStartLength >= 0 then
    FStartLength := AStartLength
  else
    FStartLength := 1;
  if AEndLength >= 0 then
    FEndLength := AEndLength
  else
    FEndLength := 1;
  SetLength(FVariants, Length(AVariants));
  for I := 0 to High(AVariants) do
    FVariants[I] := AVariants[I];
  FCount := 0;
  for LengthVal := FStartLength to FEndLength do
    FCount := FCount + IntPow(Length(FVariants), LengthVal);
end;

function TToken.Count: Int64;
begin
  Result := FCount;
end;

function TToken.Src: string;
begin
  Result := FSrc;
end;

function TToken.Get(Index: Int64): string;
var
  IndexWithOffset: Int64;
  StringLength: Integer;
  OffsetCount: Int64;
  VariantIndex: Integer;
  Parts: string;
  I: Integer;
  VariantCount: Integer;
begin
  if (Index > FCount - 1) or (Index < 0) then
    Exit('');

  if (Index = 0) and (FStartLength = 0) then
    Exit('');

  IndexWithOffset := Index;
  StringLength := FStartLength;
  for StringLength := FStartLength to FEndLength do
  begin
    OffsetCount := IntPow(Length(FVariants), StringLength);
    if IndexWithOffset < OffsetCount then
      Break;
    IndexWithOffset := IndexWithOffset - OffsetCount;
  end;

  Parts := '';
  VariantCount := Length(FVariants);
  for I := 1 to StringLength do
  begin
    if VariantCount = 0 then
      Break;
    VariantIndex := IndexWithOffset mod VariantCount;
    IndexWithOffset := IndexWithOffset div VariantCount;
    Parts := Parts + FVariants[VariantIndex];
  end;
  Result := Parts;
end;

function CreateToken(const ASrc: string; AStartLength, AEndLength: Integer;
  const AVariants: array of string): TToken;
begin
  Result := TToken.Create(ASrc, AStartLength, AEndLength, AVariants);
end;

function CreateTokenDefaults(const ASrc: string; const AVariants: array of string): TToken;
begin
  Result := TToken.Create(ASrc, 1, 1, AVariants);
end;

end.
