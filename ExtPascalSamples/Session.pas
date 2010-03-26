unit Session;

interface

uses
  ExtPascal, BasicTabPanel, MessageBoxes, LayoutWindow, AdvancedTabs,
  BorderLayout, ArrayGrid, EditableGrid, SimpleLogin, FileUpload;

type
  TSession = class(TExtThread)
  private
    BasicTabPanel : TBasicTabPanel;
    MessageBoxes  : TMessageBoxes;
    LayoutWindow  : TLayoutWindow;
    AdvancedTabs  : TAdvancedTabs;
    BorderLayout  : TBorderLayout;
    ArrayGrid     : TArrayGrid;
    EditableGrid  : TEditableGrid;
    SimpleLogin   : TSimpleLogin;
    FileUpload    : TFileUpload;
  public
    procedure AddShowSourceButton(Buttons: TExtObjectList; UnitName : string; ProcName : string = '');
    procedure SetCodePress;
  published
    procedure Home; override;
    procedure ShowSource;
    procedure ShowBasicTabPanel;
    procedure ShowMessageBoxes;
    procedure ReadButtonAjax; // Ajax
    procedure ShowLayoutWindow;
    procedure ShowAdvancedTabs;
    procedure AddTab; // Ajax
    procedure ShowBorderLayout;
    procedure SelectNodeEventServerSide;  // Ajax
    procedure ShowArrayGrid;
    procedure ShowEditableGrid;
    procedure AddPlant; // Ajax
    procedure ShowLogin;
    procedure CheckLogin; // Ajax
    procedure ShowFileUpload;
    procedure ProcessUpload;
    procedure FileDownload;
  end;

function SelfSession : TSession;

implementation

uses
  SysUtils, ExtPascalUtils, Ext, ExtForm, StrUtils,
  {$IFNDEF WebServer}FCGIApp;{$ELSE}IdExtHTTPServer;{$ENDIF}

function SelfSession : TSession; begin
  Result := TSession(CurrentFCGIThread);
end;

procedure TSession.Home;
const
  Examples : array[0..9] of record
    Name, Proc, Image, Desc : string
  end = (
    (Name: 'Basic TabPanel'; Proc: 'ShowBasicTabPanel'; Image: 'window';           Desc: 'Simple Hello World window that contains a basic TabPanel.'),
    (Name: 'Message Boxes';  Proc: 'ShowMessageBoxes';  Image: 'msg-box';          Desc: 'Different styles include confirm, alert, prompt, progress, wait and also support custom icons. Calling events passing parameters using AJAX or browser side logic'),
    (Name: 'Layout Window';  Proc: 'ShowLayoutWindow';  Image: 'window-layout';    Desc: 'A window containing a basic BorderLayout with nested TabPanel.'),
    (Name: 'Advanced Tabs';  Proc: 'ShowAdvancedTabs';  Image: 'tabs-adv';         Desc: 'Advanced tab features including tab scrolling, adding tabs programmatically using AJAX and a context menu plugin.'),
    (Name: 'Border Layout';  Proc: 'ShowBorderLayout';  Image: 'border-layout';    Desc: 'A complex BorderLayout implementation that shows nesting multiple components, sub-layouts and a treeview with Ajax and Browser side events'),
    (Name: 'Array Grid';     Proc: 'ShowArrayGrid';     Image: 'grid-array';       Desc: 'A basic read-only grid loaded from local array data that demonstrates the use of custom column renderer functions.<br/>And a simple modal dialog invoked using AJAX.'),
    (Name: 'Editable Grid';  Proc: 'ShowEditableGrid';  Image: 'grid-edit';        Desc: 'An editable grid loaded from XML that shows multiple types of grid editors as well adding new custom data records using AJAX.'),
    (Name: 'Simple Login';   Proc: 'ShowLogin';         Image: 'login.png';        Desc: 'A simple login form showing AJAX use with parameters.'),
    (Name: 'File Upload';    Proc: 'ShowFileUpload';    Image: 'fileupload.png';   Desc: 'A demo of how to give standard file upload fields a bit of Ext style.'),
    (Name: 'File Download';  Proc: 'FileDownload';      Image: 'filedownload.png'; Desc: 'Download the Advanced Configuration document (a pdf file).')
  );
  SamplesVersion = ExtPascalVersion + ' - Server on ' + {$IFNDEF FPC}'Windows - i386 - compiled by Delphi'{$ELSE}
    {$I %FPCTARGETOS%} + ' - ' + {$I %FPCTARGETCPU%} + ' - compiled by FreePascal ' + {$I %FPCVersion%} + '(' + {$I %FPCDATE%} + ')' {$ENDIF};
var
  I : integer;
  HTM : string;
begin
  SetCodePress;
  // Theme := 'gray';
  with TExtPanel.Create do begin
    Title       := 'ExtPascal Samples ' + SamplesVersion + ' - Web Server is ' + WebServer;
    RenderTo    := 'body';
    AutoWidth   := true;
    Frame       := true;
    Layout      := lyColumn;
    Collapsible := true;
    AddShowSourceButton(TBarArray, 'Session');
    for I := 0 to high(Examples) do
      with Examples[I], TExtPanel.AddTo(Items) do begin
        Title := Name;
        Frame := true;
        if Browser <> brChrome then Width := 380; // Chrome doesn't support Column layout correctly
        HTM   := '<table><td><a href=' + MethodURI(Proc) + ' target=blank>';
        if pos('.png', Image) = 0 then
          Html := HTM + '<img src=' + ExtPath + '/examples/shared/screens/' + Image + '.gif /></a></td><td>' + Desc + '</td></table>'
        else
          Html := HTM + '<img src=' + ImagePath + '/' + Image + ' /></a></td><td>' + Desc + '</td></table>';
        Collapsible := true;
      end;
    Free;
  end;
end;


procedure TSession.AddShowSourceButton(Buttons : TExtObjectList; UnitName : string; ProcName : string = ''); begin
  with TExtButton.AddTo(Buttons) do begin
    Text := 'Show Source Code';
    Handler := Ajax(ShowSource, ['UnitName', UnitName, 'ProcName', ProcName]);
  end;
end;

procedure TSession.ShowSource;
var
  Source : text;
  Line, Lines, Proc, FName : string;
begin
  Proc  := Query['ProcName'];
  FName := Query['UnitName'] + '.pas';
//  if not FileExists(FName) then FName := 'E:\Clientes\ExtPascal\cgi-bin\' + FName; // My cgi-bin path
  assign(Source, FName);
  reset(Source);
  repeat
    readln(Source, Line);
  until (pos('.' + Proc, Line) <> 0) or EOF(Source) or (Proc = '');
  Lines := '';
  while ((Proc = '') or (pos('end;', Line) <> 1)) and not EOF(Source) do begin
    Lines := Lines + Line + '\n';
    readln(Source, Line);
  end;
  Lines := Lines + 'end' + IfThen(Proc = '', '.', ';');
  close(Source);
  with TExtWindow.Create do begin
    Title  := 'Object Pascal Source: unit ' + FName + IfThen(Proc = '', '', ', procedure ' + Proc);
    Width  := 600;
    Height := 400;
    Modal  := true;
    with TExtUxCodePress.AddTo(Items) do begin
      ReadOnly := true;
      Code     := Lines;
    end;
    if Proc <> 'ShowSource' then
      AddShowSourceButton(Buttons, 'Session', 'ShowSource');
    Show;
    Free;
  end;
end;

procedure TSession.SetCodePress; begin
  SetLibrary(ExtPath + '/codepress/Ext.ux.CodePress');
end;

procedure TSession.ShowAdvancedTabs; begin
  AdvancedTabs.Free;
  AdvancedTabs := TAdvancedTabs.Create
end;

procedure TSession.AddTab; begin
  AdvancedTabs.AddTab
end;

procedure TSession.ShowArrayGrid; begin
  ArrayGrid.Free;
  ArrayGrid := TArrayGrid.Create
end;

procedure TSession.ShowBasicTabPanel; begin
  BasicTabPanel.Free;
  BasicTabPanel := TBasicTabPanel.Create;
  BasicTabPanel.Show;
end;

procedure TSession.ShowBorderLayout; begin
  BorderLayout.Free;
  BorderLayout := TBorderLayout.Create
end;

procedure TSession.SelectNodeEventServerSide; begin
  BorderLayout.SelectNodeEventServerSide
end;

procedure TSession.ShowEditableGrid; begin
  EditableGrid.Free;
  EditableGrid := TEditableGrid.Create
end;

procedure TSession.ShowLayoutWindow; begin
  LayoutWindow.Free;
  LayoutWindow := TLayoutWindow.Create;
  LayoutWindow.Show;
end;

procedure TSession.ShowLogin; begin
  SimpleLogin.Free;
  SimpleLogin := TSimpleLogin.Create;
  SimpleLogin.Show;
end;

procedure TSession.CheckLogin; begin
  SimpleLogin.Free;
  SimpleLogin.CheckLogin
end;

procedure TSession.ShowMessageBoxes; begin
  MessageBoxes.Free;
  MessageBoxes := TMessageBoxes.Create;
end;

procedure TSession.ReadButtonAjax; begin
  MessageBoxes.ReadButtonAjax
end;

procedure TSession.AddPlant; begin
  EditableGrid.AddPlant
end;

procedure TSession.ProcessUpload; begin
  FileUpload.Process
end;

procedure TSession.ShowFileUpload; begin
  FileUpload.Free;
  FileUpload := TFileUpload.Create;
  FileUpload.Show;
end;

procedure TSession.FileDownload;
var
  FileName : string;
begin
  // Put the file in the same folder of executable
  FileName := 'ExtPascal-Advanced-Configuration-eng-v6.pdf';
//  if not FileExists(FileName) then FileName := 'E:\Clientes\ExtPascal\cgi-bin\' + FileName; // My cgi-bin path
  DownloadFile(FileName);
end;

end.