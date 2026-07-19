with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;

package Json is

   type Json_Type is (Jt_Null, Jt_Bool, Jt_Number, Jt_String, Jt_Array, Jt_Object);

   type Json_Value;
   type Json_Value_Access is access all Json_Value;

   type Json_Object_Entry is record
      Key   : Unbounded_String;
      Value : Json_Value_Access;
   end record;

   package Json_Value_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Json_Value_Access);

   package Json_Object_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Json_Object_Entry);

   type Json_Value is record
      Value_Type     : Json_Type := Jt_Null;
      Bool_Value     : Boolean := False;
      Number_Value   : Long_Float := 0.0;
      String_Value   : Unbounded_String := Null_Unbounded_String;
      Array_Items    : Json_Value_Vectors.Vector;
      Object_Entries : Json_Object_Vectors.Vector;
   end record;

   function Parse (Text : String) return Json_Value_Access;
   procedure Free (Value : in out Json_Value_Access);
   function Object_Get
     (Obj : Json_Value_Access; Key : String) return Json_Value_Access;

   Parse_Error : exception;

end Json;
