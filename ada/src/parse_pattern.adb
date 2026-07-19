package body Parse_Pattern is

   function Count (Dicts : Dictionaries) return Natural is
   begin
      return Natural (Dicts.Names_List.Length);
   end Count;

   function Names (Dicts : Dictionaries) return String_List is
   begin
      return Dicts.Names_List;
   end Names;

   procedure Set_Words
     (Dicts : in out Dictionaries;
      Name  : String;
      Words : String_List)
   is
      Name_U : constant Unbounded_String := To_Unbounded_String (Name);
   begin
      for I in 1 .. Natural (Dicts.Names_List.Length) loop
         if Dicts.Names_List.Element (I) = Name_U then
            Dicts.Words_List.Replace_Element (I, Words);
            return;
         end if;
      end loop;
      Dicts.Names_List.Append (Name_U);
      Dicts.Words_List.Append (Words);
   end Set_Words;

   function Has (Dicts : Dictionaries; Name : String) return Boolean is
      Name_U : constant Unbounded_String := To_Unbounded_String (Name);
   begin
      for I in 1 .. Natural (Dicts.Names_List.Length) loop
         if Dicts.Names_List.Element (I) = Name_U then
            return True;
         end if;
      end loop;
      return False;
   end Has;

   function Get (Dicts : Dictionaries; Name : String) return String_List is
      Name_U : constant Unbounded_String := To_Unbounded_String (Name);
      Empty  : String_List;
   begin
      for I in 1 .. Natural (Dicts.Names_List.Length) loop
         if Dicts.Names_List.Element (I) = Name_U then
            return Dicts.Words_List.Element (I);
         end if;
      end loop;
      return Empty;
   end Get;

   function Chars_As_Variants (S : String) return String_List is
      Result : String_List;
   begin
      for I in S'Range loop
         Result.Append (To_Unbounded_String (String'(1 => S (I))));
      end loop;
      return Result;
   end Chars_As_Variants;

   function Is_Special (C : Character) return Boolean is
   begin
      case C is
         when '#' | '@' | '$' | '*' | '&' | '?' | '!' | '-' | '%' =>
            return True;
         when others =>
            return False;
      end case;
   end Is_Special;

   function Split_Keeping_Delimiters (Input : String) return String_List is
      Parts         : String_List;
      I             : Natural := Input'First;
      Literal_Start : Natural := Input'First;
      Len           : constant Natural := Input'Last;
      J             : Natural;

      procedure Push_Part (Part : String) is
      begin
         if Part'Length = 0 then
            return;
         end if;
         Parts.Append (To_Unbounded_String (Part));
      end Push_Part;
   begin
      if Input'Length = 0 then
         return Parts;
      end if;

      while I <= Len loop
         if I < Len and then Input (I) = '\' and then Is_Special (Input (I + 1))
         then
            if I > Literal_Start then
               Push_Part (Input (Literal_Start .. I - 1));
            end if;
            Push_Part (Input (I .. I + 1));
            I := I + 2;
            Literal_Start := I;
         elsif Is_Special (Input (I))
           and then I < Len
           and then Input (I + 1) = '{'
         then
            if I > Literal_Start then
               Push_Part (Input (Literal_Start .. I - 1));
            end if;
            J := I + 2;
            while J <= Len and then Input (J) /= '}' loop
               J := J + 1;
            end loop;
            if J <= Len and then Input (J) = '}' then
               Push_Part (Input (I .. J));
               I := J + 1;
               Literal_Start := I;
            else
               if I > Literal_Start then
                  Push_Part (Input (Literal_Start .. I - 1));
               end if;
               Push_Part (String'(1 => Input (I)));
               I := I + 1;
               Literal_Start := I;
            end if;
         elsif Is_Special (Input (I)) then
            if I > Literal_Start then
               Push_Part (Input (Literal_Start .. I - 1));
            end if;
            Push_Part (String'(1 => Input (I)));
            I := I + 1;
            Literal_Start := I;
         else
            I := I + 1;
         end if;
      end loop;

      if Literal_Start <= Len then
         Push_Part (Input (Literal_Start .. Len));
      end if;

      return Parts;
   end Split_Keeping_Delimiters;

   function Try_Parse_Int (S : String; Value : out Integer) return Boolean is
   begin
      if S'Length = 0 then
         return False;
      end if;
      for C of S loop
         if C not in '0' .. '9' then
            return False;
         end if;
      end loop;
      Value := Integer'Value (S);
      return True;
   exception
      when others =>
         return False;
   end Try_Parse_Int;

   procedure Parse_Length_With_Variants
     (Part         : String;
      Start_Length : out Integer;
      End_Length   : out Integer)
   is
      Open_Pos, Close_Pos, Dash_Pos : Natural := 0;
      Inner, Left, Right            : Unbounded_String;
      S, E, N                       : Integer;
   begin
      Start_Length := 1;
      End_Length := 1;
      for I in Part'Range loop
         if Part (I) = '{' then
            Open_Pos := I;
            exit;
         end if;
      end loop;
      if Open_Pos = 0 then
         return;
      end if;
      for I in Part'Range loop
         if Part (I) = '}' then
            Close_Pos := I;
         end if;
      end loop;
      if Close_Pos = 0 or else Close_Pos < Open_Pos then
         return;
      end if;
      Inner := To_Unbounded_String (Part (Open_Pos + 1 .. Close_Pos - 1));
      for I in 1 .. Length (Inner) loop
         if Element (Inner, I) = '-' then
            Dash_Pos := I;
            exit;
         end if;
      end loop;
      if Dash_Pos > 0 then
         Left := Unbounded_Slice (Inner, 1, Dash_Pos - 1);
         Right := Unbounded_Slice (Inner, Dash_Pos + 1, Length (Inner));
         if Try_Parse_Int (To_String (Left), S)
           and then Try_Parse_Int (To_String (Right), E)
         then
            Start_Length := S;
            End_Length := E;
         end if;
      elsif Try_Parse_Int (To_String (Inner), N) then
         Start_Length := N;
         End_Length := N;
      end if;
   end Parse_Length_With_Variants;

   function Parse_Length_With_String
     (Part         : String;
      Content      : out Unbounded_String;
      Start_Length : out Integer;
      End_Length   : out Integer) return Boolean
   is
      Open_Pos, After_Open, Close_Quote : Natural := 0;
      Rest, After_Quote, Stripped, Left, Right : Unbounded_String;
      Dash_Pos                          : Natural := 0;
      S, E, N                           : Integer;
      Has_Brace                         : Boolean := False;
   begin
      Start_Length := 1;
      End_Length := 1;
      Content := Null_Unbounded_String;

      for I in Part'First .. Part'Last - 1 loop
         if Part (I) = '{' and then Part (I + 1) = ''' then
            Open_Pos := I;
            exit;
         end if;
      end loop;
      if Open_Pos = 0 then
         return False;
      end if;

      After_Open := Open_Pos + 2;
      Rest := To_Unbounded_String (Part (After_Open .. Part'Last));
      for I in reverse 1 .. Length (Rest) loop
         if Element (Rest, I) = ''' then
            Close_Quote := I;
            exit;
         end if;
      end loop;
      if Close_Quote = 0 then
         return False;
      end if;

      Content := Unbounded_Slice (Rest, 1, Close_Quote - 1);
      After_Quote := Unbounded_Slice (Rest, Close_Quote + 1, Length (Rest));

      if Length (After_Quote) = 0
        or else (Element (After_Quote, 1) /= '}'
                 and then Element (After_Quote, 1) /= ',')
      then
         for I in 1 .. Length (After_Quote) loop
            if Element (After_Quote, I) = '}' then
               Has_Brace := True;
               exit;
            end if;
         end loop;
         if not Has_Brace then
            return False;
         end if;
      end if;

      if Length (After_Quote) > 0 and then Element (After_Quote, 1) = ',' then
         Stripped := Unbounded_Slice (After_Quote, 2, Length (After_Quote));
         if Length (Stripped) > 0
           and then Element (Stripped, Length (Stripped)) = '}'
         then
            Stripped := Unbounded_Slice (Stripped, 1, Length (Stripped) - 1);
         end if;
         for I in 1 .. Length (Stripped) loop
            if Element (Stripped, I) = '-' then
               Dash_Pos := I;
               exit;
            end if;
         end loop;
         if Dash_Pos > 0 then
            Left := Unbounded_Slice (Stripped, 1, Dash_Pos - 1);
            Right := Unbounded_Slice (Stripped, Dash_Pos + 1, Length (Stripped));
            if Try_Parse_Int (To_String (Left), S)
              and then Try_Parse_Int (To_String (Right), E)
            then
               Start_Length := S;
               End_Length := E;
            end if;
         elsif Try_Parse_Int (To_String (Stripped), N) then
            Start_Length := N;
            End_Length := N;
         end if;
      elsif Length (After_Quote) = 0
        or else Element (After_Quote, 1) /= '}'
      then
         return False;
      end if;

      return True;
   end Parse_Length_With_String;

   function Make_Literal_Token (Part : String) return Token_Type is
      Variants : String_List;
   begin
      Variants.Append (To_Unbounded_String (Part));
      return Create_Defaults (Part, Variants);
   end Make_Literal_Token;

   function Simple_Tokenizer (Part, Alphabet : String) return Token_Type is
      Start_Length, End_Length : Integer;
      Variants                 : String_List;
   begin
      Variants := Chars_As_Variants (Alphabet);
      Parse_Length_With_Variants (Part, Start_Length, End_Length);
      return Create (Part, Start_Length, End_Length, Variants);
   end Simple_Tokenizer;

   function Dictionary_Tokenizer
     (Part : String; Dicts : Dictionaries) return Token_Type
   is
      Content                  : Unbounded_String;
      Start_Length, End_Length : Integer;
      Variants                 : String_List;
   begin
      if not Parse_Length_With_String
          (Part, Content, Start_Length, End_Length)
        or else (Length (Content) > 0
                 and then not Has (Dicts, To_String (Content)))
      then
         return Make_Literal_Token (Part);
      end if;
      Variants := Get (Dicts, To_String (Content));
      return Create (Part, Start_Length, End_Length, Variants);
   end Dictionary_Tokenizer;

   function Unescape_Commas (S : String) return String is
      Result : Unbounded_String := Null_Unbounded_String;
      I      : Natural := S'First;
   begin
      while I <= S'Last loop
         if I < S'Last and then S (I) = '\' and then S (I + 1) = ',' then
            Append (Result, ',');
            I := I + 2;
         else
            Append (Result, S (I));
            I := I + 1;
         end if;
      end loop;
      return To_String (Result);
   end Unescape_Commas;

   function Words_Tokenizer (Part : String) return Token_Type is
      Content                  : Unbounded_String;
      Start_Length, End_Length : Integer;
      Variants                 : String_List;
      Work                     : Unbounded_String;
      Index                    : Natural;
   begin
      if not Parse_Length_With_String
          (Part, Content, Start_Length, End_Length)
      then
         return Make_Literal_Token (Part);
      end if;

      Work := Content;
      Index := 1;
      while Index <= Length (Work) loop
         if Index < Length (Work)
           and then Element (Work, Index) = '\'
           and then Element (Work, Index + 1) = ','
         then
            Index := Index + 2;
         elsif Element (Work, Index) = ',' then
            Variants.Append (Unbounded_Slice (Work, 1, Index - 1));
            Work := Unbounded_Slice (Work, Index + 1, Length (Work));
            Index := 1;
         else
            Index := Index + 1;
         end if;
      end loop;
      Variants.Append (Work);

      for I in 1 .. Natural (Variants.Length) loop
         Variants.Replace_Element
           (I, To_Unbounded_String (Unescape_Commas (To_String (Variants.Element (I)))));
      end loop;

      return Create (Part, Start_Length, End_Length, Variants);
   end Words_Tokenizer;

   function Part_To_Token
     (Part : String; Dicts : Dictionaries) return Token_Type
   is
      Variants : String_List;
      First    : Character;
   begin
      if Part'Length = 0 then
         return Make_Literal_Token (Part);
      end if;

      First := Part (Part'First);
      case First is
         when '#' =>
            return Simple_Tokenizer (Part, "0123456789");
         when '@' =>
            return Simple_Tokenizer (Part, "abcdefghijklmnopqrstuvwxyz");
         when '*' =>
            return Simple_Tokenizer
              (Part, "abcdefghijklmnopqrstuvwxyz0123456789");
         when '-' =>
            return Simple_Tokenizer
              (Part,
               "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");
         when '!' =>
            return Simple_Tokenizer (Part, "ABCDEFGHIJKLMNOPQRSTUVWXYZ");
         when '?' =>
            return Simple_Tokenizer
              (Part, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");
         when '&' =>
            return Simple_Tokenizer
              (Part,
               "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
         when '%' =>
            return Dictionary_Tokenizer (Part, Dicts);
         when '$' =>
            return Words_Tokenizer (Part);
         when others =>
            null;
      end case;

      if Part'Length > 1
        and then Part (Part'First) = '\'
        and then Is_Special (Part (Part'First + 1))
      then
         Variants.Append
           (To_Unbounded_String (Part (Part'First + 1 .. Part'Last)));
         return Create_Defaults (Part, Variants);
      end if;

      return Make_Literal_Token (Part);
   end Part_To_Token;

   function Parse
     (Input_Pattern : String;
      Dicts         : Dictionaries) return Token_List
   is
      Parts  : constant String_List := Split_Keeping_Delimiters (Input_Pattern);
      Result : Token_List;
      Part   : Unbounded_String;
   begin
      for I in 1 .. Natural (Parts.Length) loop
         Part := Parts.Element (I);
         if Length (Part) > 0 then
            Result.Append (Part_To_Token (To_String (Part), Dicts));
         end if;
      end loop;
      return Result;
   end Parse;

end Parse_Pattern;
