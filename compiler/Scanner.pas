unit Scanner;
{
Author: Wanderlan Santos dos Anjos, wanderlan.anjos@gmail.com
Date: dec-2008
License: <extlink http://www.opensource.org/licenses/bsd-license.php>BSD</extlink>
}
interface

type
  TTokenKind = (Undefined, Identifier, StringConstant, IntegerConstant, RealConstant, ConstantExpression,
    LabelIdentifier, TypeIdentifier, ClassIdentifier);
  TToken = class
    Lexeme       : string;
    Kind         : TTokenKind;
    RealValue    : double;
    IntegerValue : Int64;
  end;

  TSetChar = set of char;
  TScanner = class
  private
    Buf : array[1..32768] of char;
    Arq : text;
    SourceName,
    Line         : string;
    FToken       : TToken;
    CommentStyle : char;
    FEndSource   : boolean;
    LenLine      : integer;
    procedure NextChar(C: char);
    procedure FindEndComment(EndComment: string);
  protected
    FLineNumber,
    First : integer;
    procedure ScanChars(Chars: array of TSetChar; Tam : array of integer; Optional : boolean = false);
    procedure NextToken;
  public
    constructor Create(Source : string);
    destructor Destroy; override;
    procedure Report(Msg : string);
    procedure ReportExpected(Found : string);
    procedure MatchToken(T : string);
    procedure MatchTerminal(Code : char);
    property LineNumber : integer read FLineNumber;
    property ColNumber : integer read First;
    property Token : TToken read FToken;
    property EndSource : boolean read FEndSource;
  end;

implementation

uses
  SysUtils; // IntToStr, FileExists, StrToFloat, StrToInt

const
  AllChars : TSetChar = [#0..#255];

constructor TScanner.Create(Source: string); begin
  SourceName := Source;
   if FileExists(Source) then begin
     assign(Arq, Source);
     SetTextBuf(Arq, Buf);
     reset(Arq);
     First := 1;
     FToken := TToken.Create;
     NextToken;
   end
   else begin
     FEndSource := true;
     Report('Source file ' + Source + ' not found');
   end;
end;

destructor TScanner.Destroy; begin
  inherited;
  FToken.Free;
  close(Arq)
end;

procedure TScanner.MatchToken(T : string); begin
  if T <> UpperCase(FToken.Lexeme) then ReportExpected(T);
  NextToken;
end;

procedure TScanner.ScanChars(Chars : array of TSetChar; Tam : array of integer; Optional : boolean = false);
var
  I, T, Last : integer;
begin
  FToken.Lexeme := '';
  FToken.Kind   := Undefined;
  for I := 0 to high(Chars) do begin
    Last := First;
    T    := 1;
    while (Last <= LenLine) and (T <= Tam[I]) and (Line[Last] in Chars[I]) do begin
      inc(Last);
      inc(T);
    end;
    if Last > First then begin
      FToken.Lexeme := FToken.Lexeme + copy(Line, First, Last - First);
      First := Last;
    end
    else
      if Optional then exit;
  end;
end;

procedure TScanner.NextChar(C : char); begin
  if Line[First + 1] = C then begin
    FToken.Lexeme := copy(Line, First, 2);
    inc(First, 2);
  end
  else begin
    FToken.Lexeme := Line[First];
    inc(First);
  end;
  FToken.Kind := Undefined;
end;

procedure TScanner.FindEndComment(EndComment : string);
var
  PosEnd : integer;
begin
  PosEnd := pos(EndComment, Line);
  if PosEnd <> 0 then begin // End comment in same line
    CommentStyle := #0;
    First := PosEnd + length(EndComment);
  end
  else
    First := MAXINT;
end;

// Implementar {$, (*$, N�o implementado ^M ^J
procedure TScanner.NextToken;
var
  Str : string;
begin
  while not FEndSource do begin
    while First > LenLine do begin
      readln(Arq, Line);
      inc(FLineNumber);
      LenLine := length(Line);
      FEndSource := EOF(Arq) and (LenLine = 0);
      if FEndSource then exit;
      First := 1;
    end;
    // End comment across many lines
    case CommentStyle of
      #0  : ;
      '{' : begin FindEndComment('}');  continue; end;
      '*' : begin FindEndComment('*)'); continue; end;
    end;
    case Line[First] of
      ' ', #9 : begin // SkipBlank
        inc(First);
        while (First <= LenLine) and (Line[First] in [' ', #9]) do inc(First);
      end;
      'A'..'Z', '_', 'a'..'z' : begin // Identifiers
        ScanChars([['A'..'Z', 'a'..'z', '_', '0'..'9']], [255]);
        FToken.Kind := Identifier;
        // Insert in symbol table
        exit;
      end;
      ';', ',', '=', ')', '[', ']', '+', '-', '^', '@' : begin
        FToken.Lexeme := Line[First];
        FToken.Kind   := Undefined;
        inc(First);
        exit;
      end;
      '''': begin // strings
        Str := '';
        repeat
          inc(First);
          ScanChars([AllChars - [''''], ['''']], [500, 1]);
          Str := Str + FToken.Lexeme;
        until Line[First] <> '''';
        FToken.Lexeme := copy(Str, 1, length(Str)-1);
        FToken.Kind   := StringConstant;
        exit;
      end;
      '0'..'9': begin // Numbers
        ScanChars([['0'..'9'], ['.'], ['0'..'9'], ['E', 'e'], ['+', '-'], ['0'..'9']], [28, 1, 27, 1, 1, 3], true);
        FToken.Lexeme := UpperCase(FToken.Lexeme);
        if FToken.Lexeme[length(FToken.Lexeme)] in ['.', 'E', '+', '-'] then begin
          dec(First);
          SetLength(FToken.Lexeme, length(FToken.Lexeme)-1);
        end;
        if (pos('.', FToken.Lexeme) <> 0) or (pos('E', FToken.Lexeme) <> 0) then
          FToken.Kind := RealConstant
        else
          if length(FToken.Lexeme) > 18 then
            FToken.Kind := RealConstant
          else
            FToken.Kind := IntegerConstant;
        if FToken.Kind = RealConstant then
          FToken.RealValue := StrToFloat(FToken.Lexeme)
        else
          FToken.IntegerValue := StrToInt(FToken.Lexeme);
        exit;
      end;
      '(' : begin
        if Line[First + 1] = '*' then begin // Comment Style (*
          CommentStyle := '*';
          FindEndComment('*)');
        end
        else begin
          FToken.Lexeme := '(';
          FToken.Kind   := Undefined;
          inc(First);
          exit
        end;
      end;
      '/' : begin
        if Line[First + 1] = '/' then // Comment Style //
          First := MAXINT
        else begin
          FToken.Lexeme := '/';
          FToken.Kind   := Undefined;
          inc(First);
          exit
        end;
      end;
      '{' : begin CommentStyle := '{'; FindEndComment('}'); end;
      '.' : begin NextChar('.'); exit; end;
      '>',
      '<',
      ':' : begin NextChar('='); exit; end;
      '*' : begin NextChar('*'); exit; end;
      '#' : begin
        ScanChars([['#'], ['0'..'9']], [1, 5]);
        if (FToken.Lexeme = '#') and (Line[First] = '$') then begin
          ScanChars([['$'], ['0'..'9', 'A'..'F', 'a'..'f']], [1, 4]);
          FToken.Lexeme := char(StrToInt(FToken.Lexeme));
        end
        else
          FToken.Lexeme := char(StrToInt(copy(FToken.Lexeme, 2, 5)));
        FToken.Kind := StringConstant;
        exit;
      end;
      '$' : begin // Hexadecimal
        ScanChars([['$'], ['0'..'9', 'A'..'F', 'a'..'f']], [1, 16]);
        FToken.Kind := IntegerConstant;
        FToken.IntegerValue := StrToInt(FToken.Lexeme);
        exit;
      end;
    else
      Report('Invalid character ''' + Line[First] + ''' ($' + IntToHex(ord(Line[First]), 4) + ')');
      First := MAXINT;
    end;
  end;
end;

procedure TScanner.Report(Msg : string); begin
  writeln('[Error] ' + ExtractFileName(SourceName) + '('+ IntToStr(LineNumber) + ', ' + IntToStr(ColNumber) + '): ' + Msg);
  readln;
end;

procedure TScanner.ReportExpected(Found : string); begin
  Report('''' + FToken.Lexeme + ''' expected but ''' + Found + ''' found.')
end;

const
  Kinds : array[TTokenKind] of string = ('Undefined', 'Identifier', 'StringConstant', 'IntegerConstant', 'RealConstant', 'ConstantExpression',
    'LabelIdentifier', 'TypeIdentifier', 'ClassIdentifier');

procedure TScanner.MatchTerminal(Code: char);
var
  KindFound : TTokenKind;
begin
  KindFound := TTokenKind(byte(Code) - 229);
  if FToken.Kind <> KindFound then
    Report(Kinds[FToken.Kind] + ' expected but ' + Kinds[KindFound] + ' found.');
  NextToken
end;

end.