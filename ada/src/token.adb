package body Token is

   function Int_Pow (Base : Long_Long_Integer; Exp : Integer) return Long_Long_Integer is
      Result : Long_Long_Integer := 1;
   begin
      for I in 1 .. Exp loop
         Result := Result * Base;
      end loop;
      return Result;
   end Int_Pow;

   function Create
     (Src          : String;
      Start_Length : Integer;
      End_Length   : Integer;
      Variants     : String_List) return Token_Type
   is
      T : Token_Type;
   begin
      T.Src := To_Unbounded_String (Src);
      if Start_Length >= 0 then
         T.Start_Length := Start_Length;
      else
         T.Start_Length := 1;
      end if;
      if End_Length >= 0 then
         T.End_Length := End_Length;
      else
         T.End_Length := 1;
      end if;
      T.Variants := Variants;
      T.Count_Value := 0;
      for Length_Val in T.Start_Length .. T.End_Length loop
         T.Count_Value :=
           T.Count_Value
           + Int_Pow (Long_Long_Integer (Natural (T.Variants.Length)), Length_Val);
      end loop;
      return T;
   end Create;

   function Create_Defaults
     (Src      : String;
      Variants : String_List) return Token_Type
   is
   begin
      return Create (Src, 1, 1, Variants);
   end Create_Defaults;

   function Count (T : Token_Type) return Long_Long_Integer is
   begin
      return T.Count_Value;
   end Count;

   function Src (T : Token_Type) return String is
   begin
      return To_String (T.Src);
   end Src;

   function Get (T : Token_Type; Index : Long_Long_Integer) return String is
      Index_With_Offset : Long_Long_Integer;
      String_Length     : Integer;
      Offset_Count      : Long_Long_Integer;
      Variant_Index     : Integer;
      Variant_Count     : Natural;
      Parts             : Unbounded_String := Null_Unbounded_String;
   begin
      if Index > T.Count_Value - 1 or else Index < 0 then
         return "";
      end if;

      if Index = 0 and then T.Start_Length = 0 then
         return "";
      end if;

      Index_With_Offset := Index;
      String_Length := T.Start_Length;
      for L in T.Start_Length .. T.End_Length loop
         String_Length := L;
         Offset_Count :=
           Int_Pow (Long_Long_Integer (Natural (T.Variants.Length)), L);
         exit when Index_With_Offset < Offset_Count;
         Index_With_Offset := Index_With_Offset - Offset_Count;
      end loop;

      Variant_Count := Natural (T.Variants.Length);
      for I in 1 .. String_Length loop
         exit when Variant_Count = 0;
         Variant_Index :=
           Integer (Index_With_Offset mod Long_Long_Integer (Variant_Count));
         Index_With_Offset :=
           Index_With_Offset / Long_Long_Integer (Variant_Count);
         Append (Parts, T.Variants.Element (Variant_Index + 1));
      end loop;

      return To_String (Parts);
   end Get;

end Token;
