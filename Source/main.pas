{******************************************************************************}
{                                                                              }
{ grab2web 1.0                                                                 }
{                                                                              }
{ Version: MPL 1.1 / GPL 2.0 / LGPL 2.1                                        }
{                                                                              }
{ The contents of this file are subject to the Mozilla Public License Version  }
{ 1.1 (the "License"); you may not use this file except in compliance with     }
{ the License. You may obtain a copy of the License at                         }
{ http://www.mozilla.org/MPL/                                                  }
{                                                                              }
{ Software distributed under the License is distributed on an "AS IS" basis,   }
{ WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License     }
{ for the specific language governing rights and limitations under the         }
{ License.                                                                     }
{                                                                              }
{ The Initial Developer of the Original Code is                                }
{ Thomas Werner (tw@ThomasWerner-Online.de)                                    }
{ Portions created by the Initial Developer are Copyright (C) 2004             }
{ the Initial Developer. All Rights Reserved.                                  }
{                                                                              }
{ You may retrieve the latest version of this file at the Initial Developer's  }
{ page, located at http://www.ThomasWerner-Online.de                           }
{                                                                              }
{ Alternatively, the contents of this file may be used under the terms of      }
{ either the GNU General Public License Version 2 or later (the "GPL"), or     }
{ the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),     }
{ in which case the provisions of the GPL or the LGPL are applicable instead   }
{ of those above. If you wish to allow use of your version of this file only   }
{ under the terms of either the GPL or the LGPL, and not to allow others to    }
{ use your version of this file under the terms of the MPL, indicate your      }
{ decision by deleting the provisions above and replace them with the notice   }
{ and other provisions required by the GPL or the LGPL. If you do not delete   }
{ the provisions above, a recipient may use your version of this file under    }
{ the terms of any one of the MPL, the GPL or the LGPL.                        }
{                                                                              }
{******************************************************************************}

unit main;

interface

uses

  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, DSPack, DSUtil, DirectShow9, ComCtrls, ExtCtrls,
  CoolTrayIcon, Buttons, IdBaseComponent, IdComponent, IdTCPConnection,
  IdTCPClient, IdFTP, JclFileUtils, uStrings;

type

  TMainForm = class(TForm)
    CaptureGraph: TFilterGraph;
    VideoWindow: TVideoWindow;
    VideoSourceFilter: TFilter;
    StatusBar: TStatusBar;
    Timer: TTimer;
    Panel1: TPanel;
    lblCams: TLabel;
    cmbCams: TComboBox;
    lblFormats: TLabel;
    cmbFormats: TComboBox;
    TrayIcon: TCoolTrayIcon;
    lblFTPTarget: TLabel;
    edtFTPTarget: TEdit;
    lblFTPUser: TLabel;
    edtFTPUser: TEdit;
    lblFTPPass: TLabel;
    edtFTPPass: TEdit;
    btnStart: TBitBtn;
    btnStop: TBitBtn;
    Label1: TLabel;
    edtInterval: TEdit;
    ftp: TIdFTP;
    tmrUpload: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure cmbCamsChange(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
    procedure btnStart2Click(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure tmrUploadTimer(Sender: TObject);
  private
    procedure takeAPicture(path: String);
  end;

var MainForm       : TMainForm;
    CapEnum        : TSysDevEnum;
    VideoMediaTypes: TEnumMediaType;

implementation

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
  var i: integer;
  begin
    CapEnum := TSysDevEnum.Create(CLSID_VideoInputDeviceCategory);
    if CapEnum.CountFilters > 0 then begin
      for i := 0 to CapEnum.CountFilters -1 do
        cmbCams.Items.Add(CapEnum.Filters[i].FriendlyName);
      cmbCams.ItemIndex := 0;
    end;
    VideoMediaTypes := TEnumMediaType.Create;
    StatusBar.Panels[1].Text := 'Pixel: ' + intToStr(VideoWindow.Width) +' x ' +
                                intToStr(VideoWindow.Height);
  end;

procedure TMainForm.FormDestroy(Sender: TObject);
  begin
    if assigned(CapEnum) then CapEnum.Free;
    if assigned(VideoMediaTypes) then VideoMediaTypes.Free;
  end;

procedure TMainForm.TimerTimer(Sender: TObject);
  var position: int64;
      Hour, Min, Sec, MSec: Word;
  const MiliSecInOneDay = 86400000;
  begin
    if CaptureGraph.Active then begin
      with CaptureGraph as IMediaSeeking do GetCurrentPosition(position);
      DecodeTime(position div 10000 / MiliSecInOneDay, Hour, Min, Sec, MSec);
      StatusBar.Panels[0].Text := 'Uptime: ' + Format('%d:%d:%d:%d',[Hour,
                                  Min, Sec, MSec]);
    end;
  end;

procedure TMainForm.takeAPicture(path: String);
  var bmp: TBitmap;
      rct: TRect;
  begin
    bmp := TBitmap.Create;
    bmp.Canvas.CopyMode := cmSrcCopy;
    bmp.Width := VideoWindow.Width;
    bmp.Height := VideoWindow.Height;
    rct.Left := 0;
    rct.Right := bmp.Width;
    rct.Top := 0;
    rct.Bottom := bmp.Height;
    bmp.Canvas.CopyRect(rct,VideoWindow.Canvas,rct);
    bmp.SaveToFile('C:\capture.bmp');
  end;

procedure TMainForm.cmbCamsChange(Sender: TObject);
  var PinList: TPinList;
      i: integer;
  begin
    CapEnum.SelectGUIDCategory(CLSID_VideoInputDeviceCategory);
    if cmbCams.ItemIndex <> -1 then begin
      VideoSourceFilter.BaseFilter.Moniker := CapEnum.GetMoniker(
                                              cmbCams.ItemIndex);
      VideoSourceFilter.FilterGraph := CaptureGraph;
      CaptureGraph.Active := true;
      PinList := TPinList.Create(VideoSourceFilter as IBaseFilter);
      cmbFormats.Clear;
      VideoMediaTypes.Assign(PinList.First);
      for i := 0 to VideoMediaTypes.Count - 1 do
        cmbFormats.Items.Add(VideoMediaTypes.MediaDescription[i]);
      CaptureGraph.Active := false;
      PinList.Free;
      btnStart.Enabled := true;
    end;
  end;

procedure TMainForm.FormResize(Sender: TObject);
  begin
    StatusBar.Panels[1].Text := 'Pixel: ' + intToStr(VideoWindow.Width) +' x ' +
                                intToStr(VideoWindow.Height);
  end;

procedure TMainForm.TrayIconDblClick(Sender: TObject);
  begin Show; end;

procedure TMainForm.btnStart2Click(Sender: TObject);
  var PinList: TPinList;
  begin
    if cmbCams.ItemIndex = -1 then begin
      showmessage('Sie haben noch keine Videoquelle angegeben!');
      exit;
    end;
    CaptureGraph.Active := true;
    if VideoSourceFilter.FilterGraph <> nil then begin
      PinList := TPinList.Create(VideoSourceFilter as IBaseFilter);
      if cmbFormats.ItemIndex <> -1 then
        with (PinList.First as IAMStreamConfig) do
          SetFormat(VideoMediaTypes.Items[cmbFormats.ItemIndex].AMMediaType^);
      PinList.Free;
    end;
    if VideoSourceFilter.BaseFilter.DataLength > 0 then
     (CaptureGraph as IcaptureGraphBuilder2).RenderStream(@PIN_CATEGORY_PREVIEW,
        nil,VideoSourceFilter as IBaseFilter,nil,VideoWindow as IBaseFilter);
    CaptureGraph.Play;
    btnStop.Enabled := true;
    btnStart.Enabled := false;
    cmbFormats.Enabled := false;
    cmbCams.Enabled := false;
    Timer.Enabled := true;
    try    tmrUpload.Interval := strToInt(edtInterval.Text) * 1000;
    except
      showMessage('Der angegebene Intervall ist ungültig!');
      tmrUpload.Interval := 300 * 1000;
    end;
    tmrUpload.Enabled := True;
    TrayIcon.Hint := 'VideoCap - Aktiv';
  end;

procedure TMainForm.btnStopClick(Sender: TObject);
  begin
    Timer.Enabled := false;
    btnStop.Enabled := false;
    btnStart.Enabled := true;
    CaptureGraph.Stop;
    CaptureGraph.Active := False;
    cmbFormats.Enabled := true;
    cmbCams.Enabled := true;
    TrayIcon.Hint := 'VideoCap - Nicht aktiv';
    tmrUpload.Enabled := False;
  end;

procedure TMainForm.tmrUploadTimer(Sender: TObject);
  var ind : Integer;
      path: String;
      str : String;
  begin
    path := FileGetTempName('grab2') + '.bmp';
    takeAPicture(path);
    try
      if edtFTPUser.Text = '' then ftp.Username := 'Anonymous'
      else ftp.Username := edtFTPUser.Text;
      ftp.Password := edtFTPPass.Text;
      str := lowercase(trim(edtFTPTarget.Text));
      if copy(str,0,6) = 'ftp://' then str := copy(str,7,Length(str) -6);
      ind := pos('/',str);
      if ind <> 0 then FTP.Host := copy(str,0,ind -1)
      else ftp.Host := str;
      ftp.Connect();
      if ftp.Connected then begin
        try
          if ind <> 0 then
            try
              ftp.ChangeDir(copy(str,ind+1,Length(str) -ind -pos('/',
                            strReverse(str))));
            except
              showMessage('Das angegebene Verzeichnis konnte nicht geöffnet werden');
              exit;
            end;
            try
              ind := pos('/',strReverse(str));
              ftp.Put(path,copy(str,Length(str) -ind +2, ind+1));
            except
              showMessage('Das Bild konnte nicht auf den Server kopiert werden');
            end;

        finally if ftp.Connected then ftp.Disconnect;
        end;
      end else showMessage('Der angegebene Server konnte nicht erreicht werden');
    except
    end;
    deleteFile(path);
  end;

end.
