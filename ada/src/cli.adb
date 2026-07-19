with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Containers.Vectors;
with Generator; use Generator;
with Json; use Json;
with Parse_Pattern; use Parse_Pattern;
with Token; use Token;
with Wildling; use Wildling;

procedure Cli is

   Quit_Error : exception;

   package Integer_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Integer);

   type Range_Rec is record
      Start_Idx : Integer;
      End_Idx   : Integer;
   end record;

   package Range_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Range_Rec);

   type Cli_Args is record
      Selects      : Integer_Vectors.Vector;
      Ranges       : Range_Vectors.Vector;
      Check        : Boolean := False;
      Dicts        : Dictionaries;
      Patterns     : String_List;
      Help         : Boolean := False;
      Version      : Boolean := False;
   end record;

   FALLBACK_HELP : constant String :=
     "wildling - pattern based string generator" & ASCII.LF & ASCII.LF
     & "Help text unavailable.";

   function Strip_Image (N : Integer) return String is
      S : constant String := Integer'Image (N);
   begin
      if S'Length > 0 and then S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Strip_Image;

   function Strip_LL_Image (N : Long_Long_Integer) return String is
      S : constant String := Long_Long_Integer'Image (N);
   begin
      if S'Length > 0 and then S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Strip_LL_Image;

   function Parse_Range (Value : String; R : out Range_Rec) return Boolean is
      Dash           : Natural := 0;
      Left           : Unbounded_String;
      Right          : Unbounded_String;
      Start_N, End_N : Integer;
   begin
      for I in Value'Range loop
         if Value (I) = '-' then
            Dash := I;
            exit;
         end if;
      end loop;
      if Dash <= Value'First or else Dash = Value'Last then
         return False;
      end if;
      Left := To_Unbounded_String (Value (Value'First .. Dash - 1));
      Right := To_Unbounded_String (Value (Dash + 1 .. Value'Last));
      for I in 1 .. Length (Left) loop
         if Element (Left, I) not in '0' .. '9' then
            return False;
         end if;
      end loop;
      for I in 1 .. Length (Right) loop
         if Element (Right, I) not in '0' .. '9' then
            return False;
         end if;
      end loop;
      begin
         Start_N := Integer'Value (To_String (Left));
         End_N := Integer'Value (To_String (Right));
      exception
         when others =>
            return False;
      end;
      if Start_N > End_N then
         return False;
      end if;
      R.Start_Idx := Start_N;
      R.End_Idx := End_N;
      return True;
   end Parse_Range;

   function Read_File_Bytes (Path : String) return String is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      F   : File_Type;
      Buf : Stream_Element_Array (1 .. 1);
      Last : Stream_Element_Offset;
      Acc : Unbounded_String := Null_Unbounded_String;
   begin
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         Read (F, Buf, Last);
         exit when Last < Buf'First;
         Append (Acc, Character'Val (Buf (Buf'First)));
      end loop;
      Close (F);
      return To_String (Acc);
   end Read_File_Bytes;

   function Trim_Line (S : String) return String is
      First : Natural := S'First;
      Last  : Natural := S'Last;
   begin
      while First <= Last
        and then (S (First) = ' '
                  or else S (First) = ASCII.HT
                  or else S (First) = ASCII.CR
                  or else S (First) = ASCII.LF)
      loop
         First := First + 1;
      end loop;
      while Last >= First
        and then (S (Last) = ' '
                  or else S (Last) = ASCII.HT
                  or else S (Last) = ASCII.CR
                  or else S (Last) = ASCII.LF)
      loop
         Last := Last - 1;
      end loop;
      if First > Last then
         return "";
      end if;
      return S (First .. Last);
   end Trim_Line;

   function Load_Dictionary_File (Path : String) return String_List is
      Raw    : constant String := Read_File_Bytes (Path);
      Result : String_List;
      Line   : Unbounded_String := Null_Unbounded_String;
      I      : Natural := Raw'First;

      procedure Push_Line (S : String) is
         Trimmed : constant String := Trim_Line (S);
      begin
         if Trimmed'Length = 0 then
            return;
         end if;
         Result.Append (To_Unbounded_String (Trimmed));
      end Push_Line;
   begin
      while I <= Raw'Last loop
         if Raw (I) = ASCII.CR then
            Push_Line (To_String (Line));
            Line := Null_Unbounded_String;
            if I < Raw'Last and then Raw (I + 1) = ASCII.LF then
               I := I + 1;
            end if;
         elsif Raw (I) = ASCII.LF then
            Push_Line (To_String (Line));
            Line := Null_Unbounded_String;
         else
            Append (Line, Raw (I));
         end if;
         I := I + 1;
      end loop;
      if Length (Line) > 0 then
         Push_Line (To_String (Line));
      end if;
      return Result;
   end Load_Dictionary_File;

   procedure Apply_Dictionary_Path
     (Args : in out Cli_Args; Name, Path : String)
   is
      Words : String_List;
   begin
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      begin
         Words := Load_Dictionary_File (Path);
         Set_Words (Args.Dicts, Name, Words);
      exception
         when others =>
            null;
      end;
   end Apply_Dictionary_Path;

   procedure Apply_Dictionary_Json
     (Args : in out Cli_Args; Name : String; Value : Json_Value_Access)
   is
      Words : String_List;
      Item  : Json_Value_Access;
   begin
      if Value.Value_Type = Jt_Array then
         for I in 1 .. Natural (Value.Array_Items.Length) loop
            Item := Value.Array_Items.Element (I);
            case Item.Value_Type is
               when Jt_String =>
                  Words.Append (Item.String_Value);
               when Jt_Number =>
                  Words.Append
                    (To_Unbounded_String
                       (Strip_Image
                          (Integer
                             (Long_Float'Truncation (Item.Number_Value)))));
               when Jt_Bool =>
                  if Item.Bool_Value then
                     Words.Append (To_Unbounded_String ("true"));
                  else
                     Words.Append (To_Unbounded_String ("false"));
                  end if;
               when others =>
                  null;
            end case;
         end loop;
         Set_Words (Args.Dicts, Name, Words);
      elsif Value.Value_Type = Jt_String then
         Apply_Dictionary_Path (Args, Name, To_String (Value.String_Value));
      end if;
   end Apply_Dictionary_Json;

   procedure Apply_Template (Args : in out Cli_Args; Path : String) is
      Raw    : Unbounded_String;
      Root   : Json_Value_Access := null;
      Node   : Json_Value_Access;
      Val    : Json_Value_Access;
      Dicts  : Json_Value_Access;
      Number : Integer;
      R      : Range_Rec;
      Ok     : Boolean := False;
   begin
      if not Ada.Directories.Exists (Path) then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Template file not found: " & Path);
         raise Quit_Error;
      end if;
      begin
         Raw := To_Unbounded_String (Read_File_Bytes (Path));
         Root := Parse (To_String (Raw));
         Ok := True;
      exception
         when others =>
            Ok := False;
      end;
      if not Ok or else Root = null or else Root.Value_Type /= Jt_Object then
         Free (Root);
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Invalid JSON template: " & Path);
         raise Quit_Error;
      end if;

      Node := Object_Get (Root, "check");
      if Node /= null
        and then Node.Value_Type = Jt_Bool
        and then Node.Bool_Value
      then
         Args.Check := True;
      end if;

      Node := Object_Get (Root, "select");
      if Node /= null and then Node.Value_Type = Jt_Array then
         for I in 1 .. Natural (Node.Array_Items.Length) loop
            Val := Node.Array_Items.Element (I);
            Number := -1;
            if Val.Value_Type = Jt_Number then
               Number := Integer (Long_Float'Truncation (Val.Number_Value));
            elsif Val.Value_Type = Jt_String then
               begin
                  Number := Integer'Value (To_String (Val.String_Value));
               exception
                  when others =>
                     Number := -1;
               end;
            end if;
            if Number >= 0 then
               Args.Selects.Append (Number);
            end if;
         end loop;
      end if;

      Node := Object_Get (Root, "range");
      if Node /= null and then Node.Value_Type = Jt_Array then
         for I in 1 .. Natural (Node.Array_Items.Length) loop
            Val := Node.Array_Items.Element (I);
            if Val.Value_Type = Jt_String then
               if Parse_Range (To_String (Val.String_Value), R) then
                  Args.Ranges.Append (R);
               end if;
            end if;
         end loop;
      end if;

      Dicts := Object_Get (Root, "dictionaries");
      if Dicts /= null and then Dicts.Value_Type = Jt_Object then
         for I in 1 .. Natural (Dicts.Object_Entries.Length) loop
            Apply_Dictionary_Json
              (Args,
               To_String (Dicts.Object_Entries.Element (I).Key),
               Dicts.Object_Entries.Element (I).Value);
         end loop;
      end if;

      Node := Object_Get (Root, "patterns");
      if Node /= null and then Node.Value_Type = Jt_Array then
         for I in 1 .. Natural (Node.Array_Items.Length) loop
            Val := Node.Array_Items.Element (I);
            if Val.Value_Type = Jt_String then
               Args.Patterns.Append (Val.String_Value);
            end if;
         end loop;
      end if;

      Free (Root);
   end Apply_Template;

   function Parse_Args return Cli_Args is
      Result : Cli_Args;
      I      : Natural := 1;
      Arg    : Unbounded_String;
      Spec   : Unbounded_String;
      Name   : Unbounded_String;
      Path_U : Unbounded_String;
      Colon  : Natural;
      Val    : Integer;
      R      : Range_Rec;
   begin
      while I <= Ada.Command_Line.Argument_Count loop
         Arg := To_Unbounded_String (Ada.Command_Line.Argument (I));
         if Arg = "--help" or else Arg = "-h" then
            Result.Help := True;
            I := I + 1;
         elsif Arg = "--version" or else Arg = "-v" then
            Result.Version := True;
            I := I + 1;
         elsif Arg = "--check" then
            Result.Check := True;
            I := I + 1;
         elsif Arg = "--select" then
            I := I + 1;
            exit when I > Ada.Command_Line.Argument_Count;
            begin
               Val := Integer'Value (Ada.Command_Line.Argument (I));
               if Val >= 0 then
                  Result.Selects.Append (Val);
               end if;
            exception
               when others =>
                  null;
            end;
            I := I + 1;
         elsif Arg = "--range" then
            I := I + 1;
            exit when I > Ada.Command_Line.Argument_Count;
            if Parse_Range (Ada.Command_Line.Argument (I), R) then
               Result.Ranges.Append (R);
            end if;
            I := I + 1;
         elsif Arg = "--dictionary" then
            I := I + 1;
            exit when I > Ada.Command_Line.Argument_Count;
            Spec := To_Unbounded_String (Ada.Command_Line.Argument (I));
            Colon := 0;
            for J in 1 .. Length (Spec) loop
               if Element (Spec, J) = ':' then
                  Colon := J;
                  exit;
               end if;
            end loop;
            if Colon > 1 and then Colon < Length (Spec) then
               Name := Unbounded_Slice (Spec, 1, Colon - 1);
               Path_U := Unbounded_Slice (Spec, Colon + 1, Length (Spec));
               Apply_Dictionary_Path
                 (Result, To_String (Name), To_String (Path_U));
            end if;
            I := I + 1;
         elsif Arg = "--template" then
            I := I + 1;
            if I > Ada.Command_Line.Argument_Count then
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "Missing path for --template");
               raise Quit_Error;
            end if;
            Apply_Template (Result, Ada.Command_Line.Argument (I));
            I := I + 1;
         else
            Result.Patterns.Append (Arg);
            I := I + 1;
         end if;
      end loop;
      return Result;
   end Parse_Args;

   function Rtrim (S : String) return String is
      Last : Natural := S'Last;
   begin
      while Last >= S'First
        and then (S (Last) = ASCII.LF
                  or else S (Last) = ASCII.CR
                  or else S (Last) = ' '
                  or else S (Last) = ASCII.HT)
      loop
         Last := Last - 1;
      end loop;
      if Last < S'First then
         return "";
      end if;
      return S (S'First .. Last);
   end Rtrim;

   function Load_Help_Text return String is
      Exe        : constant String := Ada.Command_Line.Command_Name;
      Exe_Dir    : Unbounded_String;
      Slash      : Natural := 0;
      Candidates : array (1 .. 3) of Unbounded_String;
   begin
      for I in reverse Exe'Range loop
         if Exe (I) = '/' then
            Slash := I;
            exit;
         end if;
      end loop;
      if Slash > 0 then
         Exe_Dir := To_Unbounded_String (Exe (Exe'First .. Slash));
      else
         Exe_Dir := To_Unbounded_String ("./");
      end if;
      Candidates (1) := Exe_Dir & "help.txt";
      Candidates (2) := Exe_Dir & "../docs/help.txt";
      Candidates (3) := To_Unbounded_String ("docs/help.txt");
      for I in Candidates'Range loop
         if Ada.Directories.Exists (To_String (Candidates (I))) then
            return Rtrim (Read_File_Bytes (To_String (Candidates (I))));
         end if;
      end loop;
      return Rtrim (FALLBACK_HELP);
   end Load_Help_Text;

   function Format_List (Values : String_List) return String is
      Result : Unbounded_String;
   begin
      if Natural (Values.Length) = 0 then
         return "";
      end if;
      Result := To_Unbounded_String (" ");
      for I in 1 .. Natural (Values.Length) loop
         if I > 1 then
            Append (Result, ' ');
         end if;
         Append (Result, Values.Element (I));
      end loop;
      return To_String (Result);
   end Format_List;

   procedure Print_Check (Args : Cli_Args; W : Wildling_Type) is
      Dict_Names  : constant String_List := Names (Args.Dicts);
      Select_Strs : String_List;
      Range_Strs  : String_List;
      Gens        : constant Generator_List := Generators (W);
   begin
      for I in 1 .. Natural (Args.Selects.Length) loop
         Select_Strs.Append
           (To_Unbounded_String (Strip_Image (Args.Selects.Element (I))));
      end loop;
      for I in 1 .. Natural (Args.Ranges.Length) loop
         Range_Strs.Append
           (To_Unbounded_String
              (Strip_Image (Args.Ranges.Element (I).Start_Idx)
               & "-"
               & Strip_Image (Args.Ranges.Element (I).End_Idx)));
      end loop;

      Ada.Text_IO.Put_Line ("patterns:" & Format_List (Args.Patterns));
      Ada.Text_IO.Put_Line ("dictionaries:" & Format_List (Dict_Names));
      Ada.Text_IO.Put_Line ("select:" & Format_List (Select_Strs));
      Ada.Text_IO.Put_Line ("range:" & Format_List (Range_Strs));
      Ada.Text_IO.Put ("total: " & Strip_LL_Image (Count (W)));
      for I in 1 .. Natural (Gens.Length) loop
         Ada.Text_IO.New_Line;
         Ada.Text_IO.Put
           ("generator: "
            & Source (Gens.Element (I))
            & " "
            & Strip_LL_Image (Count (Gens.Element (I))));
      end loop;
      Ada.Text_IO.New_Line;
   end Print_Check;

   procedure Print_Value_Or_False
     (W : Wildling_Type; Index : Long_Long_Integer)
   is
      Value : Unbounded_String;
   begin
      if Get (W, Index, Value) then
         Ada.Text_IO.Put_Line (To_String (Value));
      else
         Ada.Text_IO.Put_Line ("false");
      end if;
   end Print_Value_Or_False;

   Args  : Cli_Args;
   W     : Wildling_Type;
   Value : Unbounded_String;

begin
   begin
      Args := Parse_Args;
   exception
      when Quit_Error =>
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
   end;

   if Args.Help then
      Ada.Text_IO.Put_Line (Load_Help_Text);
      return;
   end if;

   if Args.Version then
      Ada.Text_IO.Put_Line ("wildling " & WILDLING_VERSION);
      return;
   end if;

   if Natural (Args.Patterns.Length) = 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "No pattern provided. Use --help for usage information.");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   W := Create (Args.Patterns, Args.Dicts);

   if Args.Check then
      Print_Check (Args, W);
   elsif Natural (Args.Selects.Length) > 0
     or else Natural (Args.Ranges.Length) > 0
   then
      for I in 1 .. Natural (Args.Selects.Length) loop
         Print_Value_Or_False
           (W, Long_Long_Integer (Args.Selects.Element (I)));
      end loop;
      for I in 1 .. Natural (Args.Ranges.Length) loop
         for J in Args.Ranges.Element (I).Start_Idx ..
           Args.Ranges.Element (I).End_Idx
         loop
            Print_Value_Or_False (W, Long_Long_Integer (J));
         end loop;
      end loop;
   else
      while Next (W, Value) loop
         Ada.Text_IO.Put_Line (To_String (Value));
      end loop;
   end if;

end Cli;
