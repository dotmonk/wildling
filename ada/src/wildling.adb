package body Wildling is

   function Create
     (Patterns : String_List;
      Dicts    : Dictionaries) return Wildling_Type
   is
      W   : Wildling_Type;
      Gen : Generator_Type;
   begin
      W.Dicts := Dicts;
      W.Pattern_Count := 0;
      W.Internal_Index := 0;
      for I in 1 .. Natural (Patterns.Length) loop
         Gen := Generator.Create (To_String (Patterns.Element (I)), Dicts);
         W.Generators_Val.Append (Gen);
         W.Pattern_Count := W.Pattern_Count + Generator.Count (Gen);
      end loop;
      return W;
   end Create;

   function Count (W : Wildling_Type) return Long_Long_Integer is
   begin
      return W.Pattern_Count;
   end Count;

   procedure Reset (W : in out Wildling_Type) is
   begin
      W.Internal_Index := 0;
   end Reset;

   function Generators (W : Wildling_Type) return Generator_List is
   begin
      return W.Generators_Val;
   end Generators;

   function Get
     (W     : Wildling_Type;
      Index : Long_Long_Integer;
      Value : out Unbounded_String) return Boolean
   is
      Segment_Index : Long_Long_Integer := 0;
      Pattern_Index : Long_Long_Integer;
      Gen_Count     : Long_Long_Integer;
      Gen           : Generator_Type;
   begin
      Value := Null_Unbounded_String;
      if Index > W.Pattern_Count - 1 or else Index < 0 then
         return False;
      end if;

      for I in 1 .. Natural (W.Generators_Val.Length) loop
         Gen := W.Generators_Val.Element (I);
         Gen_Count := Generator.Count (Gen);
         Pattern_Index := Index - Segment_Index;
         if Pattern_Index < Gen_Count then
            Value := To_Unbounded_String (Generator.Get (Gen, Pattern_Index));
            return True;
         end if;
         Segment_Index := Segment_Index + Gen_Count;
      end loop;
      return False;
   end Get;

   function Next
     (W     : in out Wildling_Type;
      Value : out Unbounded_String) return Boolean
   is
   begin
      if W.Internal_Index = W.Pattern_Count then
         Value := Null_Unbounded_String;
         return False;
      end if;
      W.Internal_Index := W.Internal_Index + 1;
      return Get (W, W.Internal_Index - 1, Value);
   end Next;

end Wildling;
