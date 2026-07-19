with Ada.Unchecked_Deallocation;

package body Json is

   procedure Free_Value is new Ada.Unchecked_Deallocation
     (Json_Value, Json_Value_Access);

   procedure Free (Value : in out Json_Value_Access) is
   begin
      if Value = null then
         return;
      end if;
      case Value.Value_Type is
         when Jt_Array =>
            for I in 1 .. Natural (Value.Array_Items.Length) loop
               declare
                  Item : Json_Value_Access := Value.Array_Items.Element (I);
               begin
                  Free (Item);
               end;
            end loop;
         when Jt_Object =>
            for I in 1 .. Natural (Value.Object_Entries.Length) loop
               declare
                  Entry_Rec : Json_Object_Entry :=
                    Value.Object_Entries.Element (I);
               begin
                  Free (Entry_Rec.Value);
               end;
            end loop;
         when others =>
            null;
      end case;
      Free_Value (Value);
   end Free;

   function Object_Get
     (Obj : Json_Value_Access; Key : String) return Json_Value_Access
   is
      Key_U : constant Unbounded_String := To_Unbounded_String (Key);
   begin
      if Obj = null or else Obj.Value_Type /= Jt_Object then
         return null;
      end if;
      for I in 1 .. Natural (Obj.Object_Entries.Length) loop
         if Obj.Object_Entries.Element (I).Key = Key_U then
            return Obj.Object_Entries.Element (I).Value;
         end if;
      end loop;
      return null;
   end Object_Get;

   type Parser is record
      Text : Unbounded_String;
      Pos  : Natural := 1;
   end record;

   procedure Skip_Ws (P : in out Parser) is
   begin
      while P.Pos <= Length (P.Text) loop
         case Element (P.Text, P.Pos) is
            when ' ' | ASCII.HT | ASCII.LF | ASCII.CR =>
               P.Pos := P.Pos + 1;
            when others =>
               return;
         end case;
      end loop;
   end Skip_Ws;

   function Peek (P : Parser; C : Character) return Boolean is
   begin
      return P.Pos <= Length (P.Text) and then Element (P.Text, P.Pos) = C;
   end Peek;

   function Expect (P : in out Parser; C : Character) return Boolean is
   begin
      Skip_Ws (P);
      if not Peek (P, C) then
         return False;
      end if;
      P.Pos := P.Pos + 1;
      return True;
   end Expect;

   function At_End (P : Parser) return Boolean is
   begin
      return P.Pos > Length (P.Text);
   end At_End;

   function Parse_Value (P : in out Parser) return Json_Value_Access;

   function Parse_String (P : in out Parser) return Unbounded_String is
      Result : Unbounded_String := Null_Unbounded_String;
      C, Esc : Character;
      Hex    : String (1 .. 4);
      Code   : Integer;
   begin
      if not Expect (P, '"') then
         raise Parse_Error with "Expected string";
      end if;

      while P.Pos <= Length (P.Text) loop
         C := Element (P.Text, P.Pos);
         P.Pos := P.Pos + 1;
         if C = '"' then
            return Result;
         end if;
         if C = '\' then
            if P.Pos > Length (P.Text) then
               raise Parse_Error with "Unterminated escape";
            end if;
            Esc := Element (P.Text, P.Pos);
            P.Pos := P.Pos + 1;
            case Esc is
               when '"' | '\' | '/' =>
                  Append (Result, Esc);
               when 'b' =>
                  Append (Result, ASCII.BS);
               when 'f' =>
                  Append (Result, ASCII.FF);
               when 'n' =>
                  Append (Result, ASCII.LF);
               when 'r' =>
                  Append (Result, ASCII.CR);
               when 't' =>
                  Append (Result, ASCII.HT);
               when 'u' =>
                  if P.Pos + 3 > Length (P.Text) then
                     raise Parse_Error with "Invalid unicode escape";
                  end if;
                  Hex := Slice (P.Text, P.Pos, P.Pos + 3);
                  P.Pos := P.Pos + 4;
                  Code := Integer'Value ("16#" & Hex & "#");
                  Append (Result, Character'Val (Code mod 256));
               when others =>
                  raise Parse_Error with "Invalid escape";
            end case;
         else
            Append (Result, C);
         end if;
      end loop;
      raise Parse_Error with "Unterminated string";
   end Parse_String;

   function Parse_Number (P : in out Parser) return Json_Value_Access is
      Start_Pos : constant Natural := P.Pos;
      Raw       : Unbounded_String;
      V         : Json_Value_Access;
   begin
      if Peek (P, '-') then
         P.Pos := P.Pos + 1;
      end if;
      while P.Pos <= Length (P.Text)
        and then Element (P.Text, P.Pos) in '0' .. '9'
      loop
         P.Pos := P.Pos + 1;
      end loop;
      if Peek (P, '.') then
         P.Pos := P.Pos + 1;
         while P.Pos <= Length (P.Text)
           and then Element (P.Text, P.Pos) in '0' .. '9'
         loop
            P.Pos := P.Pos + 1;
         end loop;
      end if;
      if P.Pos <= Length (P.Text)
        and then (Element (P.Text, P.Pos) = 'e'
                  or else Element (P.Text, P.Pos) = 'E')
      then
         P.Pos := P.Pos + 1;
         if Peek (P, '+') or else Peek (P, '-') then
            P.Pos := P.Pos + 1;
         end if;
         while P.Pos <= Length (P.Text)
           and then Element (P.Text, P.Pos) in '0' .. '9'
         loop
            P.Pos := P.Pos + 1;
         end loop;
      end if;
      Raw := Unbounded_Slice (P.Text, Start_Pos, P.Pos - 1);
      V := new Json_Value;
      V.Value_Type := Jt_Number;
      V.Number_Value := Long_Float'Value (To_String (Raw));
      return V;
   end Parse_Number;

   function Parse_Array (P : in out Parser) return Json_Value_Access is
      V    : Json_Value_Access;
      Item : Json_Value_Access;
   begin
      if not Expect (P, '[') then
         raise Parse_Error with "Expected [";
      end if;
      V := new Json_Value;
      V.Value_Type := Jt_Array;
      Skip_Ws (P);
      if Peek (P, ']') then
         P.Pos := P.Pos + 1;
         return V;
      end if;
      loop
         Item := Parse_Value (P);
         V.Array_Items.Append (Item);
         Skip_Ws (P);
         if Peek (P, ']') then
            P.Pos := P.Pos + 1;
            return V;
         end if;
         if not Expect (P, ',') then
            Free (V);
            raise Parse_Error with "Expected , or ]";
         end if;
      end loop;
   end Parse_Array;

   function Parse_Object (P : in out Parser) return Json_Value_Access is
      V         : Json_Value_Access;
      Key       : Unbounded_String;
      Value     : Json_Value_Access;
      Entry_Rec : Json_Object_Entry;
   begin
      if not Expect (P, '{') then
         raise Parse_Error with "Expected {";
      end if;
      V := new Json_Value;
      V.Value_Type := Jt_Object;
      Skip_Ws (P);
      if Peek (P, '}') then
         P.Pos := P.Pos + 1;
         return V;
      end if;
      loop
         Skip_Ws (P);
         Key := Parse_String (P);
         Skip_Ws (P);
         if not Expect (P, ':') then
            Free (V);
            raise Parse_Error with "Expected :";
         end if;
         Value := Parse_Value (P);
         Entry_Rec.Key := Key;
         Entry_Rec.Value := Value;
         V.Object_Entries.Append (Entry_Rec);
         Skip_Ws (P);
         if Peek (P, '}') then
            P.Pos := P.Pos + 1;
            return V;
         end if;
         if not Expect (P, ',') then
            Free (V);
            raise Parse_Error with "Expected , or }";
         end if;
      end loop;
   end Parse_Object;

   function Parse_Value (P : in out Parser) return Json_Value_Access is
      C : Character;
      S : Unbounded_String;
      V : Json_Value_Access;
   begin
      Skip_Ws (P);
      if At_End (P) then
         raise Parse_Error with "Unexpected end";
      end if;
      C := Element (P.Text, P.Pos);
      if C = '{' then
         return Parse_Object (P);
      elsif C = '[' then
         return Parse_Array (P);
      elsif C = '"' then
         S := Parse_String (P);
         V := new Json_Value;
         V.Value_Type := Jt_String;
         V.String_Value := S;
         return V;
      elsif C = 't'
        and then P.Pos + 3 <= Length (P.Text)
        and then Slice (P.Text, P.Pos, P.Pos + 3) = "true"
      then
         P.Pos := P.Pos + 4;
         V := new Json_Value;
         V.Value_Type := Jt_Bool;
         V.Bool_Value := True;
         return V;
      elsif C = 'f'
        and then P.Pos + 4 <= Length (P.Text)
        and then Slice (P.Text, P.Pos, P.Pos + 4) = "false"
      then
         P.Pos := P.Pos + 5;
         V := new Json_Value;
         V.Value_Type := Jt_Bool;
         V.Bool_Value := False;
         return V;
      elsif C = 'n'
        and then P.Pos + 3 <= Length (P.Text)
        and then Slice (P.Text, P.Pos, P.Pos + 3) = "null"
      then
         P.Pos := P.Pos + 4;
         V := new Json_Value;
         V.Value_Type := Jt_Null;
         return V;
      elsif C = '-' or else C in '0' .. '9' then
         return Parse_Number (P);
      else
         raise Parse_Error with "Invalid JSON value";
      end if;
   end Parse_Value;

   function Parse (Text : String) return Json_Value_Access is
      P : Parser;
      V : Json_Value_Access;
   begin
      P.Text := To_Unbounded_String (Text);
      P.Pos := 1;
      V := Parse_Value (P);
      Skip_Ws (P);
      if not At_End (P) then
         Free (V);
         raise Parse_Error with "Trailing data";
      end if;
      return V;
   end Parse;

end Json;
