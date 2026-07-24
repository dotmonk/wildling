with Ada.Containers.Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Generator; use Generator;
with Parse_Pattern; use Parse_Pattern;
with Token; use Token;

package Wildling is

   WILDLING_VERSION : constant String := "2.0.5";

   package Generator_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Generator_Type);

   subtype Generator_List is Generator_Vectors.Vector;

   type Wildling_Type is tagged private;

   function Create
     (Patterns : String_List;
      Dicts    : Dictionaries) return Wildling_Type;

   function Count (W : Wildling_Type) return Long_Long_Integer;
   procedure Reset (W : in out Wildling_Type);

   --  Returns False when exhausted.
   function Next
     (W     : in out Wildling_Type;
      Value : out Unbounded_String) return Boolean;

   function Generators (W : Wildling_Type) return Generator_List;

   --  Returns False for out-of-range.
   function Get
     (W     : Wildling_Type;
      Index : Long_Long_Integer;
      Value : out Unbounded_String) return Boolean;

private

   type Wildling_Type is tagged record
      Dicts          : Dictionaries;
      Generators_Val : Generator_List;
      Pattern_Count  : Long_Long_Integer := 0;
      Internal_Index : Long_Long_Integer := 0;
   end record;

end Wildling;
