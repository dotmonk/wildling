with Token; use Token;

package body Generator is

   function Create
     (Input_Pattern : String;
      Dicts         : Dictionaries) return Generator_Type
   is
      G : Generator_Type;
   begin
      G.Source_Value := To_Unbounded_String (Input_Pattern);
      G.Token_Items := Parse (Input_Pattern, Dicts);
      G.Count_Value := 1;
      for I in 1 .. Natural (G.Token_Items.Length) loop
         G.Count_Value :=
           G.Count_Value * Token.Count (G.Token_Items.Element (I));
      end loop;
      return G;
   end Create;

   function Count (G : Generator_Type) return Long_Long_Integer is
   begin
      return G.Count_Value;
   end Count;

   function Source (G : Generator_Type) return String is
   begin
      return To_String (G.Source_Value);
   end Source;

   function Tokens (G : Generator_Type) return Token_List is
   begin
      return G.Token_Items;
   end Tokens;

   function Get (G : Generator_Type; Index : Long_Long_Integer) return String is
      Index_With_Offset : Long_Long_Integer;
      Token_Count       : Long_Long_Integer;
      Result            : Unbounded_String := Null_Unbounded_String;
      Tok               : Token_Type;
   begin
      if Index > G.Count_Value - 1 or else Index < 0 then
         return "";
      end if;

      Index_With_Offset := Index;
      for I in 1 .. Natural (G.Token_Items.Length) loop
         Tok := G.Token_Items.Element (I);
         Token_Count := Token.Count (Tok);
         Append
           (Result,
            Token.Get (Tok, Index_With_Offset mod Token_Count));
         Index_With_Offset := Index_With_Offset / Token_Count;
      end loop;
      return To_String (Result);
   end Get;

end Generator;
