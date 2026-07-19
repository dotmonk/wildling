with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Parse_Pattern; use Parse_Pattern;

package Generator is

   type Generator_Type is tagged private;

   function Create
     (Input_Pattern : String;
      Dicts         : Dictionaries) return Generator_Type;

   function Count (G : Generator_Type) return Long_Long_Integer;
   function Source (G : Generator_Type) return String;
   function Get (G : Generator_Type; Index : Long_Long_Integer) return String;
   function Tokens (G : Generator_Type) return Token_List;

private

   type Generator_Type is tagged record
      Source_Value : Unbounded_String;
      Token_Items  : Token_List;
      Count_Value  : Long_Long_Integer := 1;
   end record;

end Generator;
