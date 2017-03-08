{

jsonDoc.pas

Copyright 2015-2017 Stijn Sanders
Made available under terms described in file "LICENSE"
https://github.com/stijnsanders/jsonDoc

v1.1.0

}
unit jsonDoc;

{$WARN SYMBOL_PLATFORM OFF}
{$D-}
{$L-}

{

Options:
Define here or in the project settings

  JSONDOC_JSON_STRICT
    to disallow missing quotes around key names

  JSONDOC_STOREINDENTING
    to make ToString write indentation EOL's and tabs

}

interface

uses
  ComObj, ActiveX, SysUtils, WinTypes;

const
  //COM GUID's
  IID_IJSONDocument
    : TGUID = '{4A534F4E-0001-0001-C000-000000000001}';
  CLASS_JSONDocument
    : TGUID = '{4A534F4E-0001-0002-C000-000000000002}';
  IID_IJSONEnumerator
    : TGUID = '{4A534F4E-0001-0003-C000-000000000003}';
  IID_IJSONEnumerable
    : TGUID = '{4A534F4E-0001-0004-C000-000000000004}';
  IID_IJSONDocArrayBuilder
    : TGUID = '{4A534F4E-0001-0005-C000-000000000005}';
  IID_IJSONDocWithReUse
    : TGUID = '{4A534F4E-0001-0006-C000-000000000006}';

//ADDITION for TRethinkDB: IRethinkDBTerm is thread-unsafe anyway,
// so avoid locking with reference counting IJSONDocument instances as well:

type
  //see also TInterfacedObject
  TTHREADUNSAFEInterfacedObject = class(TObject, IInterface)
  protected
    FRefCount: Integer;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    class function NewInstance: TObject; override;
    property RefCount: Integer read FRefCount;
  end;



type
{
  IJSONDocument interface
  the base JSON document interface that provides access to a set of
  key-value pairs.
  use ToString and Parse to convert JSON to and from string values.
  use ToVarArray to access the key-value pairs as a [x,2] variant array.
  use Clear to re-use a JSON doc for parsing or building a new similar
  document and keep the allocated memory for keys and values.
  see also: JSON function
}
  IJSONDocument = interface(IUnknown)
    ['{4A534F4E-0001-0001-C000-000000000001}']
    function Get_Item(const Key: WideString): OleVariant; stdcall;
    procedure Set_Item(const Key: WideString; const Value: OleVariant); stdcall;
    function Parse(const JSONData: WideString): IJSONDocument; stdcall;
    function ToString: WideString; stdcall;
    function ToVarArray:OleVariant; stdcall;
    procedure Clear; stdcall;
    property Item[const Key: WideString]: OleVariant
      read Get_Item write Set_Item; default;
    procedure Delete(const Key: WideString); stdcall;
  end;

{
  IJSONEnumerator interface
  use IJSONEnumerator to enumerate a document's key-value pairs
  see also: JSONEnum function
}
  //TODO: IEnumVariant?
  IJSONEnumerator = interface(IUnknown)
    ['{4A534F4E-0001-0003-C000-000000000003}']
    function EOF: boolean; stdcall;
    function Next: boolean; stdcall;
    function Get_Key: WideString; stdcall;
    function Get_Value: OleVariant; stdcall;
    procedure Set_Value(const Value: OleVariant); stdcall;
    property Key: WideString read Get_Key;
    property Value: OleVariant read Get_Value write Set_Value;
  end;

{
  IJSONEnumerable interface
  used to get a IJSONEnumerable instance for a document
  see also: JSONEnum function
}
  IJSONEnumerable = interface(IUnknown)
    ['{4A534F4E-0001-0004-C000-000000000004}']
    function NewEnumerator: IJSONEnumerator; stdcall;
  end;

{
  IJSONDocArrayBuilder interface
  use IJSONDocArrayBuilder to build an array of similar documents,
  ideally in combination with a single IJSONDocument instance and
  IJSONDocument.Clear to re-use the memory allocated for keys and values
  see also: JSONDocArr function
}
  IJSONDocArrayBuilder = interface(IUnknown)
    ['{4A534F4E-0001-0005-C000-000000000005}']
    function Get_Item(Index: integer): IJSONDocument; stdcall;
    procedure Set_Item(Index: integer; Doc: IJSONDocument); stdcall;
    function Add(Doc: IJSONDocument): integer; stdcall;
    function AddJson(const Data: WideString): integer; stdcall;
    procedure LoadItem(Index: integer; Doc: IJSONDocument); stdcall;
    function Count: integer; stdcall;
    function ToString: WideString; stdcall;
    procedure Clear; stdcall;
    property Item[Idx: integer]: IJSONDocument
      read Get_Item write Set_Item; default;
  end;

{
  IJSONDocWithReUse interface
  used internally to enable re-use of allocated keys
  see also: TJSONDocument Parse and Clear
}
  IJSONDocWithReUse = interface(IUnknown)
    ['{4A534F4E-0001-0006-C000-000000000006}']
    function ReUse(const Key: WideString): OleVariant; stdcall;
  end;

{
  TJSONDocument class
  the default IJSONDocument implementation
  see also: JSON function
}
  TJSONDocument = class(TTHREADUNSAFEInterfacedObject,
    IJSONDocument, IJSONEnumerable, IJSONDocWithReUse)
  private
    FElementIndex,FElementSize:integer;
    FElements:array of record
      SortIndex,LoadIndex:integer;
      Key:WideString;
      Value:OleVariant;
    end;
    FLoadIndex,FGotIndex,FGotSorted:integer;
    FGotMatch:boolean;
    function GetKeyIndex(const Key: WideString): boolean;
  protected
    function Get_Item(const Key: WideString): OleVariant; stdcall;
    procedure Set_Item(const Key: WideString; const Value: OleVariant); stdcall;
    function ReUse(const Key: WideString): OleVariant; stdcall;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
    function Parse(const JSONData: WideString): IJSONDocument; stdcall;
    function JSONToString: WideString; stdcall;
    function IJSONDocument.ToString=JSONToString;
    function ToVarArray:OleVariant; stdcall;
    procedure Clear; stdcall;
    property Item[const Key: WideString]: OleVariant
      read Get_Item write Set_Item; default;
    function NewEnumerator: IJSONEnumerator; stdcall;
    procedure Delete(const Key: WideString); stdcall;
  end;

{
  TJSONEnumerator class
  the default IJSONEnumerator implementation
  see also: JSONEnum function
}
  TJSONEnumerator = class(TTHREADUNSAFEInterfacedObject, IJSONEnumerator)
  private
    FData:TJSONDocument;
    FIndex: integer;
  public
    constructor Create(Data: TJSONDocument);
    destructor Destroy; override;
    function EOF: boolean; stdcall;
    function Next: boolean; stdcall;
    function Get_Key: WideString; stdcall;
    function Get_Value: OleVariant; stdcall;
    procedure Set_Value(const Value: OleVariant); stdcall;
  end;

{
  TJSONDocArrayBuilder class
  the default IJSONDocArrayBuilder implementation
  see also: JSONDocArr function
}
  TJSONDocArrayBuilder= class(TTHREADUNSAFEInterfacedObject, IJSONDocArrayBuilder)
  private
    FItems:array of WideString;
    FItemsCount,FItemsSize,FTotalLength:integer;
  protected
    function Get_Item(Index: integer): IJSONDocument; stdcall;
    procedure Set_Item(Index: integer; Doc: IJSONDocument); stdcall;
    function Add(Doc: IJSONDocument): integer; stdcall;
    function AddJson(const Data: WideString): integer; stdcall;
    procedure LoadItem(Index: integer; Doc: IJSONDocument); stdcall;
    function JSONToString: WideString; stdcall;
    function IJSONDocArrayBuilder.ToString=JSONToString;
    function Count: integer; stdcall;
    procedure Clear; stdcall;
  public
    constructor Create;
    destructor Destroy; override;
  end;

{
  EJSONException class types
  exception types thrown from TJSONDocument's Parse and ToString
}
  EJSONException=class(Exception);
  EJSONDecodeException=class(EJSONException);
  EJSONEncodeException=class(EJSONException);

{
  JSON function: JSON document factory
  call JSON without parameters do create a new blank document
}
function JSON: IJSONDocument; overload;

{
  JSON function: JSON document builder
  pass an array of alternately keys and values,
  suffix key with opening brace to start an embedded document,
  and key of a single closing brace to close it.
}
function JSON(const x: array of OleVariant): IJSONDocument; overload;

{
  JSON function: JSON document converter
  pass a single variant to have it converted to an IJSONDocument interface
  or a string with JSON parsed into a IJSONDocument
  or nil when VarIsNull
}
function JSON(const x: OleVariant): IJSONDocument; overload;

{
  JSONEnum function
  get a new enumerator to enumeratare the key-value pairs in the document
}
function JSONEnum(x: IJSONDocument): IJSONEnumerator; overload; //inline;
function JSONEnum(const x: OleVariant): IJSONEnumerator; overload;
function JSON(x: IJSONEnumerator): IJSONDocument; overload; //inline;
function JSONEnum(x: IJSONEnumerator): IJSONEnumerator; overload; //inline;

{
  JSONDocArray function
  get a new IJSONDocArrayBuilder
}
function JSONDocArray: IJSONDocArrayBuilder; overload;
function JSONDocArray(const Items:array of IJSONDocument):
  IJSONDocArrayBuilder; overload;

implementation

uses
  Classes, Variants;

{ TTHREADUNSAFEInterfacedObject }

procedure TTHREADUNSAFEInterfacedObject.AfterConstruction;
begin
  //inherited;//?
  dec(FRefCount);//see constructor
end;

procedure TTHREADUNSAFEInterfacedObject.BeforeDestruction;
begin
  inherited;
  if RefCount<>0 then System.Error(reInvalidPtr);
end;

class function TTHREADUNSAFEInterfacedObject.NewInstance: TObject;
begin
  Result:=inherited NewInstance;
  //see AfterConstruction, prevent detroy while creating
  TTHREADUNSAFEInterfacedObject(Result).FRefCount:=1;
end;

function TTHREADUNSAFEInterfacedObject.QueryInterface(const IID: TGUID;
  out Obj): HResult;
begin
  if GetInterface(IID,Obj) then Result:=0 else Result:=E_NOINTERFACE;
end;

function TTHREADUNSAFEInterfacedObject._AddRef: Integer;
begin
  inc(FRefCount);
  Result:=FRefCount;
end;

function TTHREADUNSAFEInterfacedObject._Release: Integer;
begin
  dec(FRefCount);
  Result:=FRefCount;
  if Result=0 then Destroy;
end;

{ TJSONDocument }

procedure TJSONDocument.AfterConstruction;
begin
  inherited;
  FElementIndex:=0;
  FElementSize:=0;
  FGotIndex:=0;
  FGotSorted:=0;
  FGotMatch:=false;
  FLoadIndex:=0;
end;

destructor TJSONDocument.Destroy;
var
  i:integer;
begin
  for i:=0 to FElementIndex-1 do VarClear(FElements[i].Value);
  inherited;
end;

function TJSONDocument.GetKeyIndex(const Key: WideString):boolean;
var
  a,b,c,d,x:integer;
begin
  //case sensitivity?
  //check last getindex, speeds up set right after get
  if FGotMatch and (CompareStr(Key,FElements[FGotIndex].Key)=0) then
   begin
    //assert FGotIndex=FSorted[FGotSorted];
    Result:=true;
   end
  else
   begin
    a:=0;
    b:=FElementIndex-1;
    d:=FElementIndex;
    FGotMatch:=false;//default
    while b>=a do
     begin
      c:=(a+b) div 2;
      d:=FElements[c].SortIndex;
      //if c=a? c=b?
      x:=CompareStr(Key,FElements[d].Key);
      if x=0 then
       begin
        a:=c;
        b:=c-1;
        FGotMatch:=true;
       end
      else
        if x<0 then
          if b=c then dec(b) else b:=c
        else
          if a=c then inc(a) else a:=c;
     end;
    FGotSorted:=a;
    FGotIndex:=d;
    Result:=FGotMatch;
   end;
end;

function TJSONDocument.Get_Item(const Key: WideString): OleVariant;
begin
  if (Self<>nil) and GetKeyIndex(Key)
    and (FElements[FGotIndex].LoadIndex=FLoadIndex) then
    Result:=FElements[FGotIndex].Value
  else
    Result:=Null;
end;

function TJSONDocument.ReUse(const Key: WideString): OleVariant;
begin
  if (Self<>nil) and GetKeyIndex(Key) then
   begin
    FElements[FGotIndex].LoadIndex:=FLoadIndex;
    Result:=FElements[FGotIndex].Value;
   end
  else
    Result:=Null;
end;

procedure TJSONDocument.Set_Item(const Key: WideString;
  const Value: OleVariant);
var
  i:integer;
const
  GrowStep=$20;//not too much, not too little (?)
begin
  //if ((VarType(Value) and varArray)<>0) and (VarArrayDimCount(v)>1) then
  //  raise EJSONException.Create(
  //    'VarArray: multi-dimensional arrays not supported');
  if not GetKeyIndex(Key) then
   begin
    if FElementIndex=FElementSize then
     begin
      inc(FElementSize,GrowStep);
      SetLength(FElements,FElementSize);
     end;
    for i:=FElementIndex-1 downto FGotSorted do
      FElements[i+1].SortIndex:=FElements[i].SortIndex;
    FGotIndex:=FElementIndex;
    inc(FElementIndex);
    FElements[FGotSorted].SortIndex:=FGotIndex;
    FElements[FGotIndex].Key:=Key;
   end;
  FElements[FGotIndex].Value:=Value;
  FElements[FGotIndex].LoadIndex:=FLoadIndex;
  //TODO: if VarType(Value)=varEmpty then drop element
  //FDirty:=true;
end;

function TJSONDocument.Parse(const JSONData: WideString): IJSONDocument;
var
  i,l:integer;
  function SkipWhiteSpace:WideChar;
  begin
    while (i<=l) and (jsonData[i]<=' ') do inc(i);
    if i<=l then Result:=jsonData[i] else Result:=#0;
  end;
  function ExVicinity(di:integer):WideString;
  const
    VicinityExtent=8;
  begin
    if di<=VicinityExtent then
      Result:=#13#10'(#'+IntToStr(di)+')"'+Copy(jsonData,1,di-1)+
        ' >>> '+jsonData[di]+' <<< '+Copy(jsonData,di+1,VicinityExtent)+'"'
    else
      Result:=#13#10'(#'+IntToStr(di)+')"...'+
        Copy(jsonData,di-VicinityExtent,VicinityExtent)+
        ' >>> '+jsonData[di]+' <<< '+Copy(jsonData,di+1,VicinityExtent)+'"';
  end;
  procedure Expect(c:WideChar;const msg:string);
  begin
    while (i<=l) and (jsonData[i]<=' ') do inc(i);
    if (i>l) or (jsonData[i]<>c) then
      raise EJSONDecodeException.Create(msg+ExVicinity(i));
    inc(i);
  end;
  procedure GetStringIndexes(var i1,i2:integer);
  begin
    i1:=i;
    while (i<=l) and (jsonData[i]<>'"') do
     begin
      if jsonData[i]='\' then inc(i);//just skip all to skip any '"'
      inc(i);
     end;
    i2:=i;
    inc(i);
  end;
  function GetStringValue(i1,i2:integer):WideString;
  var
    ii,di,u,v,w:integer;
  begin
    //assert jsonData[i1-1]='"'
    //assert jsonData[i2]='"';
    SetLength(Result,i2-i1);
    ii:=1;
    di:=i1;
    while di<i2 do
     begin
      //assert ii<=Length(Result);
      if jsonData[di]='\' then
       begin
        inc(di);
        case AnsiChar(jsonData[di]) of
          '"','\','/':Result[ii]:=jsonData[di];
          'b':Result[ii]:=#8;
          't':Result[ii]:=#9;
          'n':Result[ii]:=#10;
          'f':Result[ii]:=#12;
          'r':Result[ii]:=#13;
          'u':
           begin
            w:=0;
            for u:=0 to 3 do
             begin
              inc(di);
              v:=word(jsonData[di]);
              case v of
                $30..$39:w:=(w shl 4) or (v and $F);
                $41..$5A,$61..$7A:w:=(w shl 4) or ((v and $1F)+9);
                else raise EJSONDecodeException.Create(
                  'JSON Invalid espace sequence'+ExVicinity(di));
              end;
             end;
            Result[ii]:=WideChar(w);
           end;
          else raise EJSONDecodeException.Create(
            'JSON Unknown escape sequence'+ExVicinity(di));
        end;
       end
      else
        Result[ii]:=jsonData[di];
      inc(di);
      inc(ii);
     end;
    SetLength(Result,ii-1);
  end;
const
  stackGrowStep=$20;//not too much, not too little (?)
  arrGrowStep=$20;
var
  InObjectOrArray:boolean;
  k1,k2,v1,v2,a1,ai,al:integer;
  d:IJSONDocument;
  a:array of OleVariant;
  at:TVarType;
  procedure SetValue(const v:OleVariant);
  begin
    if InObjectOrArray then
      d[GetStringValue(k1,k2)]:=v
    else
     begin
      if ai=al then
       begin
        inc(al,arrGrowStep);//not too much, not too little (?)
        SetLength(a,al);
       end;
      a[ai]:=v;
      //assert (VarType(v) and varArray)=0
      //detect same type elements array
      if at=varEmpty then at:=VarType(v) else
        case at of
          //TODO: what with signed/unsigned mixed?
          varSmallint://i2
            if not(VarType(v) in [varSmallint,
              varShortInt,varByte]) then at:=varVariant;
          varInteger://i4
            if not(VarType(v) in [varSmallint,
              varInteger,varShortInt,varByte,varWord]) then at:=varVariant;
          varWord:
            if not(VarType(v) in [varSmallint,
              varByte,varWord]) then at:=varVariant;
          varLongWord:
            if not(VarType(v) in [varSmallint,
              varShortInt,varByte,varWord,varLongWord]) then at:=varVariant;
          varInt64:
            if not(VarType(v) in [varSmallint,varInteger,varShortInt,
              varByte,varWord,varLongWord,varInt64]) then at:=varVariant;
          varVariant:;//Already creating an VarArray of variants
          //TODO: more?
          else if at<>VarType(v) then at:=varVariant;
        end;
      inc(ai);
     end;
  end;
  function GetArrayValue:OleVariant;
  var
    ii,jj:integer;
  begin
    if not(VarTypeIsValidArrayType(at)) then at:=varVariant;
    Result:=VarArrayCreate([0,ai-a1-1],at);
    ii:=a1;
    jj:=0;
    while ii<ai do
     begin
      Result[jj]:=a[ii];
      VarClear(a[ii]);
      inc(ii);
      inc(jj);
     end;
    ai:=a1;
  end;
var
  firstItem,b:boolean;
  stack:array of record
    k1,k2:integer;
    d:IJSONDocument;
  end;
  stackIndex,stackSize:integer;
  ods:char;
  key:WideString;
  d1:IJSONDocument;
  dr:IJSONDocWithReUse;
  da:IJSONDocArrayBuilder;
  da0,da1:integer;
  v:OleVariant;
  v64:int64;
begin
  //Clear;? let caller decide.
  i:=1;
  l:=Length(jsonData);
  //object starts
  Expect('{','JSON doesn''t define an object, "{" expected.');
  stackSize:=0;
  stackIndex:=0;
  ai:=0;
  al:=0;
  da:=nil;
  da0:=0;
  da1:=0;
  InObjectOrArray:=true;
  firstItem:=true;

  {$if CompilerVersion >= 24}
  ods:=FormatSettings.DecimalSeparator;
  {$else}
  ods:=DecimalSeparator;
  {$ifend}

  try

    {$if CompilerVersion >= 24}
    FormatSettings.DecimalSeparator:='.';
    {$else}
    DecimalSeparator:='.';
    {$ifend}

    d:=Self;
    //main loop over key/values and nested objects/arrays
    while (i<=l) and (stackIndex<>-1) do
     begin
      if firstItem then firstItem:=false else
        Expect(',','JSON element not delimited by comma');
      if InObjectOrArray and (SkipWhiteSpace<>'}') then
       begin
        //key string
        {$IFDEF JSONDOC_JSON_STRICT}
        Expect('"','JSON key string not enclosed in double quotes');
        GetStringIndexes(k1,k2);
        {$ELSE}
        if SkipWhiteSpace='"' then
         begin
          inc(i);
          GetStringIndexes(k1,k2);
         end
        else
         begin
          k1:=i;
          while (i<=l) and (jsonData[i]>' ') and
            (jsonData[i]<>':') and (jsonData[i]<>'"') do inc(i);
          k2:=i;
         end;
        {$ENDIF}
        Expect(':','JSON key, value not separated by colon');
       end;
      //value
      case AnsiChar(SkipWhiteSpace) of
        '{','['://object or array
         begin
          b:=InObjectOrArray;
          if jsonData[i]='{' then
           begin
            //an object starts
            if da=nil then
              if InObjectOrArray then
               begin
                key:=GetStringValue(k1,k2);
                if d.QueryInterface(IID_IJSONDocWithReUse,dr)=S_OK then
                 begin
                  v:=dr.ReUse(key);
                  dr:=nil;
                 end
                else
                  v:=Null;
                if (VarType(v) in [varDispatch,varUnknown]) and
                  (IUnknown(v).QueryInterface(IID_IJSONDocument,d1)=S_OK) then
                  d1:=nil
                else
                 begin
                  v:=JSON;
                  d[key]:=v;
                 end;
               end
              else
               begin
                if ai=al then
                 begin
                  inc(al,arrGrowStep);//not too much, not too little (?)
                  SetLength(a,al);
                 end;
                v:=JSON;
                a[ai]:=v;
                //detect same type elements array
                if at=varEmpty then at:=varUnknown else
                  if at<>varUnknown then at:=varVariant;
                inc(ai);
               end
            else
              if da0=stackIndex then da1:=i;
            InObjectOrArray:=true;
           end
          else
           begin
            if da=nil then
              if d.QueryInterface(IID_IJSONDocWithReUse,dr)=S_OK then
               begin
                key:=GetStringValue(k1,k2);
                v:=dr.ReUse(key);
                dr:=nil;
                if (VarType(v) in [varDispatch,varUnknown]) and
                  (IUnknown(v).QueryInterface(IID_IJSONDocArrayBuilder,da)=S_OK) then
                 begin
                  da0:=stackIndex+1;
                  da1:=0;//see first '{' above
                 end;
               end;
            InObjectOrArray:=false;
           end;
          inc(i);
          //push onto stack
          if stackIndex=stackSize then
           begin
            inc(stackSize,stackGrowStep);
            SetLength(stack,stackSize);
           end;
          if b then //was InObjectOrArray?
           begin
            stack[stackIndex].k1:=k1;
            stack[stackIndex].k2:=k2;
            stack[stackIndex].d:=d;
           end
          else
           begin
            stack[stackIndex].k1:=a1;
            stack[stackIndex].k2:=at;
            stack[stackIndex].d:=nil;
           end;
          inc(stackIndex);
          firstItem:=true;
          if da=nil then
            if InObjectOrArray then
              d:=IUnknown(v) as IJSONDocument
            else
             begin
              a1:=ai;
              at:=varEmpty;//used to detect same type elements array
             end;
         end;

        '}',']':;//empty object or array, drop into close array below

        '"'://string
         begin
          inc(i);
          GetStringIndexes(v1,v2);
          if da=nil then SetValue(GetStringValue(v1,v2));
         end;

        '0'..'9','-'://number
         begin
          b:=jsonData[i]='-';
          v1:=i;
          if b then inc(i);
          if da=nil then
           begin
            v64:=0;
            while (i<=l) and (AnsiChar(jsonData[i]) in ['0'..'9']) do
             begin
              v64:=v64*10+(word(jsonData[i]) and $F);//TODO: detect overflow
              inc(i);
             end;
            if AnsiChar(jsonData[i]) in ['.','e','E'] then
             begin
              //float
              inc(i);
              while (i<=l) and (AnsiChar(jsonData[i]) in
                ['0'..'9','-','+','e','E']) do inc(i);
              //try except EConvertError?
              SetValue(StrToFloat(Copy(jsonData,v1,i-v1)));
             end
            else
             begin
              //integer
              if v64>=$80000000 then //int64
                if b then SetValue(-v64) else SetValue(v64)
              else if v64>=$80 then //int32
                if b then SetValue(-integer(v64)) else SetValue(integer(v64))
              else //int8
                if b then SetValue(-SmallInt(v64)) else SetValue(SmallInt(v64));
             end;
           end
          else
           begin
            //skip
            while (i<=l) and (AnsiChar(jsonData[i]) in ['0'..'9']) do inc(i);
            if AnsiChar(jsonData[i]) in ['.','e','E'] then
             begin
              inc(i);
              while (i<=l) and (AnsiChar(jsonData[i]) in
                ['0'..'9','-','+','e','E']) do inc(i);
             end;
           end;
         end;

        't'://true
         begin
          inc(i);
          Expect('r','JSON true misspelled');
          Expect('u','JSON true misspelled');
          Expect('e','JSON true misspelled');
          if da=nil then SetValue(true);
         end;
        'f'://false
         begin
          inc(i);
          Expect('a','JSON false misspelled');
          Expect('l','JSON false misspelled');
          Expect('s','JSON false misspelled');
          Expect('e','JSON false misspelled');
          if da=nil then SetValue(false);
         end;
        'n'://null
         begin
          inc(i);
          Expect('u','JSON null misspelled');
          Expect('l','JSON null misspelled');
          Expect('l','JSON null misspelled');
          if da=nil then SetValue(Null);
         end;

        else raise EJSONDecodeException.Create(
          'JSON Unrecognized value type'+ExVicinity(i));
      end;
      if not firstItem then
       begin
        b:=true;
        while b do
         begin
          v:=Null;
          if InObjectOrArray then
            b:=SkipWhiteSpace='}'
          else
            if SkipWhiteSpace=']' then
             begin
              if da=nil then v:=GetArrayValue;
             end
            else
              b:=false;
          if b then
           begin
            inc(i);
            //pop from stack
            if stackIndex=0 then
             begin
              //EndIndex:=i;
              dec(stackIndex);//stackindex:=-1;
              b:=false;
             end
            else
             begin
              dec(stackIndex);
              if stack[stackIndex].d=nil then
               begin
                a1:=stack[stackIndex].k1;
                at:=stack[stackIndex].k2;
                InObjectOrArray:=false;
               end
              else
               begin
                if da=nil then d:=stack[stackIndex].d;
                k1:=stack[stackIndex].k1;
                k2:=stack[stackIndex].k2;
                stack[stackIndex].d:=nil;
                InObjectOrArray:=true;
               end;
              if da<>nil then
                if stackIndex=da0 then
                  da.AddJSON(Copy(jsonData,da1,i-da1))
                else
                  if stackIndex=da0-1 then
                    da:=nil;//done
             end;
            //set array
            if (da=nil) and (VarType(v)<>varNull) then SetValue(v);
           end;
         end;
       end;
     end;
    if stackIndex<>-1 then raise EJSONDecodeException.Create(
      'JSON with '+IntToStr(stackIndex+1)+' objects or arrays not closed');
  finally
    {$if CompilerVersion >= 24}
    FormatSettings.DecimalSeparator:=ods;
    {$else}
    DecimalSeparator:=ods;
    {$ifend}
  end;
  Result:=Self;
end;

function TJSONDocument.JSONToString: WideString;
  function EncodeStr(const x:OleVariant):WideString;
  const
    resGrowStep=$100;
    hex:array[0..15] of WideChar=(
      '0','1','2','3','4','5','6','7',
      '8','9','A','B','C','D','E','F');
  var
    xx:WideString;
    i,j,k,l:integer;
    w:word;
  begin
    xx:=VarToWideStr(x);
    l:=Length(xx);
    SetLength(Result,l);
    i:=1;
    j:=0;
    k:=l;
    while i<=l do
     begin
      w:=word(xx[i]);
      case w of
        0..31,word('"'),word('\'),word('/'):
         begin
          if j+2>k then
           begin
            k:=((k div resGrowStep)+1)*resGrowStep;
            SetLength(Result,k);
           end;
          inc(j);
          Result[j]:='\';
          inc(j);
          case w of
            8:Result[j]:='b';
            9:Result[j]:='t';
            10:Result[j]:='n';
            12:Result[j]:='f';
            13:Result[j]:='r';
            word('"'),word('\'),word('/'):Result[j]:=xx[i];
            else
             begin
              Result[j]:='u';
              if j+4>k then
               begin
                k:=((k div resGrowStep)+1)*resGrowStep;
                SetLength(Result,k);
               end;
              inc(j);Result[j]:=hex[w shr 12];
              inc(j);Result[j]:=hex[w shr 8 and $F];
              inc(j);Result[j]:=hex[w shr 4 and $F];
              inc(j);Result[j]:=hex[w and $F];
             end;
          end;
         end;
        else
         begin
          if j>=k then
           begin
            k:=((k div resGrowStep)+1)*resGrowStep;
            SetLength(Result,k);
           end;
          inc(j);
          Result[j]:=WideChar(w);
         end;
      end;
      inc(i);
     end;
    SetLength(Result,j);
  end;
const
  stackGrowStep=$20;
var
  e:IJSONEnumerator;
  a:OleVariant;
  ai:integer;
  al:integer;
  firstItem:boolean;
  stack:array of record
    e:IJSONEnumerator;
    a:OleVariant;
    ai,al:integer;
  end;
  stackLength,stackIndex:integer;
  function ExTrace:string;
  var
    i:integer;
  begin
    Result:='';
    if VarType(a)<>varNull then Result:=' #'+IntToStr(ai);
    if (e<>nil) and not(e.EOF) then Result:=Result+' "'+e.Key+'"'+Result;
    i:=stackIndex;
    while i<>0 do
     begin
      dec(i);
      if VarType(stack[i].a)<>varNull then Result:=' #'+IntToStr(stack[i].ai-1)+Result;
      if (stack[i].e<>nil) and not(stack[i].e.EOF) then Result:=Result+' "'+stack[i].e.Key+'"'+Result;
     end;
  end;
const
  resultGrowStep=$4000;
var
  wi,wl:cardinal;
{$IFDEF JSONDOC_STOREINDENTING}
const
  tabs=#13#10#9#9#9#9#9#9#9#9#9#9#9#9#9#9;
var
  tabIndex:integer;
{$ENDIF}
  procedure w(const xx:WideString);
  var
    xl:cardinal;
  begin
    xl:=Length(xx);
    while wi+xl>wl do
     begin
      //grow
      inc(wl,resultGrowStep);
      SetLength(Result,wl);
     end;
    Move(xx[1],Result[wi+1],xl*2);
    inc(wi,xl);
  end;
  procedure wv(const v:OleVariant);
  var
    vt:TVarType;
    uu:IUnknown;
    d:IJSONDocument;
    de:IJSONEnumerable;
    da:IJSONDocArrayBuilder;
  begin
    vt:=VarType(v);
    //if (vt and varByRef)<>0 then
    //  raise EJSONEncodeException.Create('VarByRef: not implemented'+ExTrace);
    if (vt and varArray)=0 then
     begin
      //not an array, plain value
      case vt and varTypeMask of
        varNull:w('null');
        varSmallint,varInteger,varShortInt,
        varByte,varWord,varLongWord,varInt64:
          w(VarToWideStr(v));
        varSingle,varDouble,varCurrency:
          w(FloatToStr(v));//?
        varDate:
         begin
          //w(FloatToStr(VarToDateTime(v)));//?
          w('"');
          //TODO:"yyyy-mm-dd hh:nn:ss.zzz"? $date?
          w(FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz',VarToDateTime(v)));
          w('"');
         end;
        varOleStr:
         begin
          w('"');
          w(EncodeStr(VarToWideStr(v)));
          w('"');
         end;
        varBoolean:
          if v then w('true') else w('false');
        varDispatch,varUnknown:
         begin
          uu:=IUnknown(v);
          if uu=nil then w('null')
          else
          if uu.QueryInterface(IID_IJSONEnumerable,de)=S_OK then
           begin
            //push onto stack
            if stackIndex=stackLength then
             begin
              inc(stackLength,stackGrowStep);
              SetLength(stack,stackLength);
             end;
            stack[stackIndex].e:=e;
            stack[stackIndex].a:=a;
            stack[stackIndex].ai:=ai;
            stack[stackIndex].al:=al;
            inc(stackIndex);
            e:=de.NewEnumerator;
            a:=Null;
            w('{');
            firstItem:=true;
            {$IFDEF JSONDOC_STOREINDENTING}
            inc(tabIndex);
            {$ENDIF}
            de:=nil;
           end
          else
          if uu.QueryInterface(IID_IJSONDocument,d)=S_OK then
           begin
            //revert to ToString
            w(d.ToString);
            d:=nil;
           end
          else
          if uu.QueryInterface(IID_IJSonDocArrayBuilder,da)=S_OK then
           begin
            //TODO: re-do indenting
            w(da.ToString);
            da:=nil;
           end
          else
          //IRegExp2? IStream? IPersistStream?
            raise EJSONEncodeException.Create(
              'No supported interface found on object'+ExTrace);
         end;
        else raise EJSONEncodeException.Create(
          'Unsupported variant type '+IntToHex(vt,4)+ExTrace);
      end;
     end
    else
     begin
      //TODO: if (vt and varTypeMask)=varByte then BLOB?
      //start an array
      if VarArrayDimCount(v)>1 then //TODO:
        raise EJSONEncodeException.Create(
          'VarArray: multi-dimensional arrays not supported'+ExTrace);
      if VarType(a)<>varNull then
       begin
        //push onto stack
        if stackIndex=stackLength then
         begin
          inc(stackLength,stackGrowStep);
          SetLength(stack,stackLength);
         end;
        stack[stackIndex].e:=e;
        stack[stackIndex].a:=a;
        stack[stackIndex].ai:=ai;
        stack[stackIndex].al:=al;
        inc(stackIndex);
        e:=nil;
       end;
      a:=v;
      ai:=VarArrayLowBound(v,1)-1;
      al:=VarArrayHighBound(v,1)+1;
      w('[');
      firstItem:=true;
      {$IFDEF JSONDOC_STOREINDENTING}
      inc(tabIndex);
      {$ENDIF}
     end;
  end;
var
  ods:char;
  lastItem:boolean;
begin
  if Self=nil then
   begin
    Result:='null';
    Exit;
   end;
  wi:=1;
  wl:=resultGrowStep;
  SetLength(Result,wl);
  Result[1]:='{';

  stackLength:=0;
  stackIndex:=0;
  e:=TJSONEnumerator.Create(Self);
  a:=Null;
  ai:=0;

  {$if CompilerVersion >= 24}
  ods:= FormatSettings.DecimalSeparator;
  {$else}
  ods:=DecimalSeparator;
  {$ifend}
  try
    {$if CompilerVersion >= 24}
    FormatSettings.DecimalSeparator:='.';
    {$else}
    DecimalSeparator:='.';
    {$ifend}

    //w('{');//see above
    firstItem:=true;
    {$IFDEF JSONDOC_STOREINDENTING}
    tabIndex:=3;
    {$ENDIF}
    while not((e<>nil) and e.EOF and (VarType(a)=varNull)) do
     begin
      lastItem:=false;//default
      if VarType(a)=varNull then
       begin
        //in document
        if (e<>nil) and (e.Next) then
         begin
          if firstItem then firstItem:=false else w(',');
          {$IFDEF JSONDOC_STOREINDENTING}
          w(Copy(tabs,1,tabIndex));
          {$ENDIF}
          w('"');
          w(EncodeStr(e.Key));
          {$IFDEF JSONDOC_STOREINDENTING}
          w('": ');
          {$ELSE}
          w('":');
          {$ENDIF}
          wv(e.Value);
         end
        else
         begin
          {$IFDEF JSONDOC_STOREINDENTING}
          dec(tabIndex);
          if not firstItem then w(Copy(tabs,1,tabIndex));
          {$ENDIF}
          firstItem:=false;
          lastItem:=true;
          w('}');
         end;
       end;
      if VarType(a)<>varNull then
       begin
        //in array
        inc(ai);
        if ai=al then
         begin
          {$IFDEF JSONDOC_STOREINDENTING}
          dec(tabIndex);
          if not firstItem then w(Copy(tabs,1,tabIndex));
          {$ENDIF}
          firstItem:=false;
          lastItem:=e=nil;
          a:=Null;
          w(']');
         end
        else
         begin
          if firstItem then firstItem:=false else w(',');
          {$IFDEF JSONDOC_STOREINDENTING}
          w(Copy(tabs,1,tabIndex));
          {$ENDIF}
          wv(a[ai]);
         end;
       end;
      if lastItem and (stackIndex<>0) then
       begin
        //pop from stack
        dec(stackIndex);
        e:=stack[stackIndex].e;
        a:=stack[stackIndex].a;
        ai:=stack[stackIndex].ai;
        al:=stack[stackIndex].al;
        stack[stackIndex].e:=nil;
        VarClear(stack[stackIndex].a);
        //assert firstItem=false
       end;
     end;

    SetLength(Result,wi);

  finally
    {$if CompilerVersion >= 24}
    FormatSettings.DecimalSeparator:=ods;
    {$else}
    DecimalSeparator:=ods;
    {$ifend}
  end;
end;

function TJSONDocument.ToVarArray: OleVariant;
var
  i,l:integer;
begin
  if Self=nil then
   begin
    Result:=Null;
    Exit;
   end;
  l:=0;
  for i:=0 to FElementIndex-1 do
    if FElements[i].LoadIndex=FLoadIndex then inc(l);
      //and not(VarIsNull(FElements[i].Value))?
  Result:=VarArrayCreate([0,l-1,0,1],varVariant);
  l:=0;
  for i:=0 to FElementIndex-1 do
    if FElements[i].LoadIndex=FLoadIndex then
     begin
      Result[l,0]:=FElements[i].Key;
      Result[l,1]:=FElements[i].Value;
      inc(l);
     end;
end;

procedure TJSONDocument.Clear;
var
  i:integer;
  uu:IUnknown;
  d:IJSONDocument;
  da:IJSONDocArrayBuilder;
begin
  //FDirty:=false;
  for i:=0 to FElementIndex-1 do
    if VarType(FElements[i].Value)=varUnknown then
     begin
      uu:=IUnknown(FElements[i].Value);
      if uu.QueryInterface(IID_IJSONDocument,d)=S_OK then
       begin
        d.Clear;
        d:=nil;
       end
      else
      if uu.QueryInterface(IID_IJSONDocArrayBuilder,da)=S_OK then
       begin
        da.Clear;
        da:=nil;
       end
      else
        VarClear(FElements[i].Value);
     end
    else
      VarClear(FElements[i].Value);
  FGotMatch:=false;
  inc(FLoadIndex);
end;

procedure TJSONDocument.Delete(const Key: WideString);
var
  i:integer;
  uu:IUnknown;
  d:IJSONDocument;
begin
  if GetKeyIndex(Key) then
   begin
    i:=FGotIndex;
    if VarType(FElements[i].Value)=varUnknown then
     begin
      uu:=IUnknown(FElements[i].Value);
      if uu.QueryInterface(IID_IJSONDocument,d)=S_OK then
        d.Clear
      else
        VarClear(FElements[i].Value);
     end
    else
      VarClear(FElements[i].Value);
    FElements[i].LoadIndex:=FLoadIndex-1;
   end;
  //else raise?
  //FDirty:=true;
end;

function TJSONDocument.NewEnumerator: IJSONEnumerator;
begin
  Result:=TJSONEnumerator.Create(Self);
end;

{ JSON }

function JSON:IJSONDocument; //overload;
begin
  Result:=TJSONDocument.Create as IJSONDocument;
end;

function JSON(const x:array of OleVariant):IJSONDocument; //overload;
var
  i,l,si,sl:integer;
  s:array of IJSONDocument;
  d:IJSONDocument;
  key:WideString;
begin
  d:=TJSONDocument.Create;//d:=JSON;
  si:=0;
  sl:=0;
  i:=0;
  l:=Length(x);
  while i<l do
   begin
    key:=VarToWideStr(x[i]);
    inc(i);
    if (key<>'') and (key[1]='}') then
     begin
      while (key<>'') and (key[1]='}') do
       begin
        //pop from stack
        if si=0 then
          raise EJSONException.Create('JSON builder: closing more embedded documents than opened #'+IntToStr(i))
        else
         begin
          dec(si);
          d:=s[si];
          s[si]:=nil;
         end;
        key:=Copy(key,2,Length(key)-1);
       end;
      if key<>'' then
        raise EJSONException.Create('JSON builder: "}" not allowed as key prefix #'+IntToStr(i));
     end
    else
      if (key<>'') and (key[Length(key)]='{') then
       begin
        //push on stack
        if si=sl then
         begin
          inc(sl,8);//growstep
          SetLength(s,sl);
         end;
        s[si]:=d;
        d:=TJSONDocument.Create;
        s[si][Copy(key,1,Length(key)-1)]:=d;
        inc(si);
       end
      else
        if i=l then
          raise EJSONException.Create('JSON builder: last key is missing value')
        else
         begin
          d[key]:=x[i];
          inc(i);
         end;
   end;
  //any left open?
  if si=0 then Result:=d else Result:=s[si-1];
end;

function JSON(const x: OleVariant): IJSONDocument; overload;
begin
  case VarType(x) of
    varNull,varEmpty:Result:=nil;//raise?
    varOleStr,varString:
     begin
      Result:=TJSONDocument.Create as IJSONDocument;
      Result.Parse(VarToWideStr(x));
     end;
    else
      Result:=IUnknown(x) as IJSONDocument;
  end;
end;

function JSONEnum(x: IJSONDocument): IJSONEnumerator;
begin
  if x=nil then
    Result:=TJSONEnumerator.Create(nil)
  else
    Result:=(x as IJSONEnumerable).NewEnumerator;
end;

function JSONEnum(const x: OleVariant): IJSONEnumerator;
begin
  if VarIsNull(x) then
    Result:=TJSONEnumerator.Create(nil)
  else
    Result:=(IUnknown(x) as IJSONEnumerable).NewEnumerator;
end;

function JSON(x: IJSONEnumerator): IJSONDocument;
begin
  Result:=IUnknown(x.Value) as IJSONDocument;
end;

function JSONEnum(x: IJSONEnumerator): IJSONEnumerator;
begin
  if (x=nil) or VarIsNull(x.Value) then
    Result:=TJSONEnumerator.Create(nil)
  else
    Result:=(IUnknown(x.Value) as IJSONEnumerable).NewEnumerator;
end;

{ TJSONEnumerator }

constructor TJSONEnumerator.Create(Data: TJSONDocument);
begin
  inherited Create;
  FData:=Data;
  FIndex:=-1;
  //TODO: hook into TJSONDocument destructor?
end;

destructor TJSONEnumerator.Destroy;
begin
  FData:=nil;
  inherited;
end;

function TJSONEnumerator.EOF: boolean;
var
  i:integer;
begin
  if FData=nil then
    Result:=true
  else
   begin
    i:=FIndex;
    if i=-1 then i:=0;
    while (i<FData.FElementIndex) and
      (FData.FElements[i].LoadIndex<>FData.FLoadIndex) do
      inc(i);
    Result:=i>=FData.FElementIndex;
   end;
end;

function TJSONEnumerator.Next: boolean;
begin
  if FData=nil then
    Result:=false
  else
   begin
    inc(FIndex);
    while (FIndex<FData.FElementIndex) and
      (FData.FElements[FIndex].LoadIndex<>FData.FLoadIndex) do
      inc(FIndex);
    Result:=FIndex<FData.FElementIndex;
   end;
end;

function TJSONEnumerator.Get_Key: WideString;
begin
  if (FIndex<0) or (FData=nil) or (FIndex>=FData.FElementIndex) then
    raise ERangeError.Create('Out of range')
  else
    Result:=FData.FElements[FIndex].Key;
end;

function TJSONEnumerator.Get_Value: OleVariant;
begin
  if (FIndex<0) or (FData=nil) or (FIndex>=FData.FElementIndex) then
    raise ERangeError.Create('Out of range')
  else
    Result:=FData.FElements[FIndex].Value;
end;

procedure TJSONEnumerator.Set_Value(const Value: OleVariant);
begin
  if (FIndex<0) or (FData=nil) or (FIndex>=FData.FElementIndex) then
    raise ERangeError.Create('Out of range')
  else
    FData.FElements[FIndex].Value:=Value;
end;

{ JSONDocArray }

function JSONDocArray: IJSONDocArrayBuilder; overload;
begin
  Result:=TJSONDocArrayBuilder.Create;
end;

function JSONDocArray(const Items:array of IJSONDocument):
  IJSONDocArrayBuilder; overload;
var
  i:integer;
begin
  Result:=TJSONDocArrayBuilder.Create;
  for i:=0 to Length(Items)-1 do Result.Add(Items[i]);
end;

{ TJSONDocArrayBuilder }

constructor TJSONDocArrayBuilder.Create;
begin
  inherited Create;
  FItemsCount:=0;
  FItemsSize:=0;
  FTotalLength:=0;
end;

destructor TJSONDocArrayBuilder.Destroy;
begin
  SetLength(FItems,0);
  inherited;
end;

function TJSONDocArrayBuilder.Count: integer;
begin
  Result:=FItemsCount;
end;

procedure TJSONDocArrayBuilder.Clear;
var
  i:integer;
begin
  for i:=0 to FItemsCount-1 do FItems[i]:='';
  FItemsCount:=0;
end;

procedure TJSONDocArrayBuilder.LoadItem(Index: integer;
  Doc: IJSONDocument);
begin
  if (Index<0) or (Index>=FItemsCount) then
    raise ERangeError.Create('Index out of range');
  Doc.Clear;
  if FItems[Index]<>'null' then Doc.Parse(FItems[Index]);
  //else?
end;

function TJSONDocArrayBuilder.Get_Item(Index: integer): IJSONDocument;
begin
  if (Index<0) or (Index>=FItemsCount) then
    raise ERangeError.Create('Index out of range');
  //parse from string here assuming this won't be needed much
  if FItems[Index]='null' then Result:=nil else Result:=JSON(FItems[Index]);
end;

function TJSONDocArrayBuilder.Add(Doc: IJSONDocument): integer;
begin
  if FItemsCount=FItemsSize then
   begin
    inc(FItemsSize,$400);//grow
    SetLength(FItems,FItemsSize);
   end;
  //ToString here to save on persisting effort later
  if Doc=nil then
    FItems[FItemsCount]:='null'
  else
    FItems[FItemsCount]:=Doc.ToString;
  inc(FTotalLength,Length(FItems[FItemsCount]));
  Result:=FItemsCount;
  inc(FItemsCount);
end;

function TJSONDocArrayBuilder.AddJSON(const Data: WideString): integer;
begin
  if FItemsCount=FItemsSize then
   begin
    inc(FItemsSize,$400);//grow
    SetLength(FItems,FItemsSize);
   end;
  //TODO: check valid JSON?
  FItems[FItemsCount]:=Data;
  inc(FTotalLength,Length(Data));
  Result:=FItemsCount;
  inc(FItemsCount);
end;

procedure TJSONDocArrayBuilder.Set_Item(Index: integer;
  Doc: IJSONDocument);
var
  v:WideString;
begin
  if (Index<0) or (Index>=FItemsCount) then
    raise ERangeError.Create('Index out of range');
  if Doc=nil then
    v:='null'
  else
    v:=Doc.ToString;
  inc(FTotalLength,Length(v)-Length(FItems[Index]));
  FItems[Index]:=v;
end;

function TJSONDocArrayBuilder.JSONToString: WideString;
var
  i,x,l:integer;
begin
  SetLength(Result,FTotalLength+1+FItemsCount);
  i:=0;
  x:=1;
  while i<FItemsCount do
   begin
    Result[x]:=',';
    inc(x);
    l:=Length(FItems[i]);
    Move(FItems[i][1],Result[x],l*2);
    inc(x,l);
    inc(i);
   end;
  Result[1]:='[';
  Result[x]:=']';
end;

end.

