unit FileUpload;

interface

uses
  Ext;

type
  TFileUpload = class(TExtWindow)
    constructor Create;
  published
    procedure Process;
  end;

implementation

uses
  SysUtils, Session;

procedure TFileUpload.Process; begin
  // process your file here, by example loading a database table with it
  // or reject it using by example: Response := '{success:false,message:"The file is invalid"}';
  with SelfSession do
    if FileExists(FileUploadedFullName) then
      DeleteFile(FileUploadedFullName);
end;

constructor TFileUpload.Create;
var
  F : TExtFormPanel;
  SubmitAction : TExtFormActionSubmit;
begin
  inherited;
  SelfSession.MaxUploadSize := 0; // My demo site won�t write data ;)
  SelfSession.SetCodePress;
  Modal := true;
  Title := 'File Upload Window';
  F     := TExtFormPanel.Create;
  with F.AddTo(Items) do begin
    FileUpload := true;
    Frame      := true;
    Width      := 300;
    LabelWidth := 20;
    with TExtFormFieldText.AddTo(Items) do begin
      FieldLabel := 'File';
      InputType  := itFile;
    end;
    with TExtButton.AddTo(Buttons) do begin
      Text := 'Upload';
      SubmitAction := TExtFormActionSubmit.Create;
      with SubmitAction do begin
        Url       := MethodURI(Process); // Post upload process
        WaitMsg   := 'Uploading your file...';
        WaitTitle := 'Wait please';
        Success   := ExtMessageBox.Alert('Success', 'File: %1.result.file uploaded on /uploads folder');
        Failure   := ExtMessageBox.Alert('Upload Error', '%1.result.message')
      end;
      Handler := TExtFormBasic(GetForm).Submit(SubmitAction);
    end;
    with TExtButton.AddTo(Buttons) do begin
      Text    := 'Reset';
      Handler := TExtFormBasic(GetForm).Reset;
    end;
    SelfSession.AddShowSourceButton(Buttons, 'FileUpload');
  end;
end;

end.
