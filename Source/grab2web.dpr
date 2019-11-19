program grab2web;

uses
  Forms,
  uTMainForm in 'uTMainForm.pas' {MainForm},
  uTUploadThread in 'uTUploadThread.pas',
  uTSettings in 'uTSettings.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'grab2web 0.9';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
