unit Generator;

{$mode objfpc}{$H+}

interface

uses
  Token, ParsePattern;

type
  TGenerator = class
  private
    FSource: string;
    FTokens: TTokenArray;
    FCount: Int64;
  public
    constructor Create(const InputPattern: string; Dictionaries: TDictionaries);
    destructor Destroy; override;
    function Count: Int64;
    function Source: string;
    function Get(Index: Int64): string;
    function Tokens: TTokenArray;
  end;

function CreateGenerator(const InputPattern: string; Dictionaries: TDictionaries): TGenerator;

implementation

constructor TGenerator.Create(const InputPattern: string; Dictionaries: TDictionaries);
var
  I: Integer;
begin
  inherited Create;
  FSource := InputPattern;
  FTokens := ParsePattern.ParsePattern(InputPattern, Dictionaries);
  FCount := 1;
  for I := 0 to High(FTokens) do
    FCount := FCount * FTokens[I].Count;
end;

destructor TGenerator.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FTokens) do
    FTokens[I].Free;
  SetLength(FTokens, 0);
  inherited Destroy;
end;

function TGenerator.Count: Int64;
begin
  Result := FCount;
end;

function TGenerator.Source: string;
begin
  Result := FSource;
end;

function TGenerator.Tokens: TTokenArray;
begin
  Result := FTokens;
end;

function TGenerator.Get(Index: Int64): string;
var
  IndexWithOffset: Int64;
  I: Integer;
  TokenCount: Int64;
begin
  if (Index > FCount - 1) or (Index < 0) then
    Exit('');

  Result := '';
  IndexWithOffset := Index;
  for I := 0 to High(FTokens) do
  begin
    TokenCount := FTokens[I].Count;
    Result := Result + FTokens[I].Get(IndexWithOffset mod TokenCount);
    IndexWithOffset := IndexWithOffset div TokenCount;
  end;
end;

function CreateGenerator(const InputPattern: string; Dictionaries: TDictionaries): TGenerator;
begin
  Result := TGenerator.Create(InputPattern, Dictionaries);
end;

end.
