with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;

package Token is

   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Unbounded_String);

   subtype String_List is String_Vectors.Vector;

   type Token_Type is tagged private;

   function Create
     (Src          : String;
      Start_Length : Integer;
      End_Length   : Integer;
      Variants     : String_List) return Token_Type;

   function Create_Defaults
     (Src      : String;
      Variants : String_List) return Token_Type;

   function Count (T : Token_Type) return Long_Long_Integer;
   function Src (T : Token_Type) return String;
   function Get (T : Token_Type; Index : Long_Long_Integer) return String;

   function Int_Pow (Base : Long_Long_Integer; Exp : Integer) return Long_Long_Integer;

private

   type Token_Type is tagged record
      Src          : Unbounded_String;
      Start_Length : Integer := 1;
      End_Length   : Integer := 1;
      Variants     : String_List;
      Count_Value  : Long_Long_Integer := 0;
   end record;

end Token;
