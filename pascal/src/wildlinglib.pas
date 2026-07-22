unit WildlingLib;

{$mode objfpc}{$H+}

interface

uses
  Generator, ParsePattern, Token;

const
  WILDLING_VERSION = '2.0.2';

type
  TGeneratorArray = array of TGenerator;

  TWildling = class
  private
    FDictionaries: TDictionaries;
    FOwnsDictionaries: Boolean;
    FGenerators: TGeneratorArray;
    FPatternCount: Int64;
    FInternalIndex: Int64;
  public
    constructor Create(const Patterns: array of string; Dictionaries: TDictionaries);
    destructor Destroy; override;
    function CurrentIndex: Int64;
    function Count: Int64;
    procedure Reset;
    { Returns False when exhausted; Value holds the string when True. }
    function Next(out Value: string): Boolean;
    function Generators: TGeneratorArray;
    { Returns False for out-of-range; Value is the combination when True. }
    function Get(AIndex: Int64; out Value: string): Boolean;
  end;

function CreateWildling(const Patterns: array of string;
  Dictionaries: TDictionaries = nil): TWildling;

implementation

constructor TWildling.Create(const Patterns: array of string; Dictionaries: TDictionaries);
var
  I: Integer;
  Gen: TGenerator;
begin
  inherited Create;
  FOwnsDictionaries := Dictionaries = nil;
  if Dictionaries = nil then
    FDictionaries := TDictionaries.Create
  else
    FDictionaries := Dictionaries;

  SetLength(FGenerators, Length(Patterns));
  FPatternCount := 0;
  for I := 0 to High(Patterns) do
  begin
    Gen := CreateGenerator(Patterns[I], FDictionaries);
    FGenerators[I] := Gen;
    FPatternCount := FPatternCount + Gen.Count;
  end;
  FInternalIndex := 0;
end;

destructor TWildling.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FGenerators) do
    FGenerators[I].Free;
  SetLength(FGenerators, 0);
  if FOwnsDictionaries then
    FDictionaries.Free;
  inherited Destroy;
end;

function TWildling.CurrentIndex: Int64;
begin
  Result := FInternalIndex;
end;

function TWildling.Count: Int64;
begin
  Result := FPatternCount;
end;

procedure TWildling.Reset;
begin
  FInternalIndex := 0;
end;

function TWildling.Generators: TGeneratorArray;
begin
  Result := FGenerators;
end;

function TWildling.Get(AIndex: Int64; out Value: string): Boolean;
var
  SegmentIndex: Int64;
  I: Integer;
  PatternIndex: Int64;
  GenCount: Int64;
begin
  Value := '';
  if (AIndex > FPatternCount - 1) or (AIndex < 0) then
    Exit(False);

  SegmentIndex := 0;
  for I := 0 to High(FGenerators) do
  begin
    GenCount := FGenerators[I].Count;
    PatternIndex := AIndex - SegmentIndex;
    if PatternIndex < GenCount then
    begin
      Value := FGenerators[I].Get(PatternIndex);
      Exit(True);
    end;
    SegmentIndex := SegmentIndex + GenCount;
  end;
  Result := False;
end;

function TWildling.Next(out Value: string): Boolean;
begin
  if FInternalIndex = FPatternCount then
  begin
    Value := '';
    Exit(False);
  end;
  Inc(FInternalIndex);
  Result := Get(FInternalIndex - 1, Value);
end;

function CreateWildling(const Patterns: array of string;
  Dictionaries: TDictionaries): TWildling;
begin
  Result := TWildling.Create(Patterns, Dictionaries);
end;

end.
