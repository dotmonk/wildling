with Ada.Containers.Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Token; use Token;

package Parse_Pattern is

   type Dictionaries is tagged private;

   procedure Set_Words
     (Dicts : in out Dictionaries;
      Name  : String;
      Words : String_List);

   function Has (Dicts : Dictionaries; Name : String) return Boolean;
   function Get (Dicts : Dictionaries; Name : String) return String_List;
   function Names (Dicts : Dictionaries) return String_List;
   function Count (Dicts : Dictionaries) return Natural;

   package Token_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Token_Type);

   subtype Token_List is Token_Vectors.Vector;

   function Parse
     (Input_Pattern : String;
      Dicts         : Dictionaries) return Token_List;

   function Chars_As_Variants (S : String) return String_List;

private

   package Word_List_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => String_List,
      "="          => String_Vectors."=");

   type Dictionaries is tagged record
      Names_List : String_List;
      Words_List : Word_List_Vectors.Vector;
   end record;

end Parse_Pattern;
