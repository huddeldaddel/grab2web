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

unit uTMainForm;

interface

uses

  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, DSPack, DSUtil, DirectShow9, ComCtrls, ExtCtrls,
  CoolTrayIcon, Buttons, JclFileUtils, uStrings, uTUploadThread, uTSettings,
  AppEvnts, ImgList, Menus;

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
    tmrUpload: TTimer;
    ImageGrabber: TSampleGrabber;
    hider: TTimer;
    TrayPopup: TPopupMenu;
    Beenden1: TMenuItem;
    Minimieren1: TMenuItem;
    Minimieren2: TMenuItem;
    popup: TImageList;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure cmbCamsChange(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
    procedure btnStart2Click(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure tmrUploadTimer(Sender: TObject);
    procedure hiderTimer(Sender: TObject);
    procedure Minimieren2Click(Sender: TObject);
    procedure Minimieren1Click(Sender: TObject);
    procedure Beenden1Click(Sender: TObject);
  private
    copyFolder     : String;
    settings       : TSettings;
    upload         : TUploadThread;
    uploadActive   : Boolean;
    transfer       : int64;
    CapEnum        : TSysDevEnum;
    pPath          : String;
    VideoMediaTypes: TEnumMediaType;
    procedure takeAPicture(path: String);
    procedure handleThreadDeath(Sender:TObject; success:Boolean; Msg: String;
              size: Cardinal);
    function  setCam(quiet: Boolean): Boolean;
  end;

var MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
  var i: integer;
  begin
    settings := TSettings.Create;
    settings.loadFromRegistry;

    edtFTPTarget.Text := settings.server;
    edtFTPUser.Text := settings.user;
    edtFTPPass.Text := settings.passw;
    edtInterval.Text := intToStr(settings.interv);

    transfer := 0;
    pPath := FileGetTempName('g2w') + '.bmp';
    uploadActive := False;
    CapEnum := TSysDevEnum.Create(CLSID_VideoInputDeviceCategory);
    if CapEnum.CountFilters > 0 then begin
      for i := 0 to CapEnum.CountFilters -1 do begin
        cmbCams.Items.Add(CapEnum.Filters[i].FriendlyName);
        if (CapEnum.Filters[i].FriendlyName = settings.cam) then
          cmbCams.ItemIndex := i;
      end;
    end;
    VideoMediaTypes := TEnumMediaType.Create;
    if cmbCams.ItemIndex <> -1 then cmbCamsChange(cmbCams);
    StatusBar.Panels[1].Text := 'Pixel: ' + intToStr(VideoWindow.Width) +' x ' +
                                intToStr(VideoWindow.Height);

    if (ParamCount >= 1) then
      for i := 1 to ParamCount do begin
        if (ParamStr(i) = '-r') and (not setCam(True)) then exit;
        if copy(ParamStr(i),0,2) = '-c' then
          copyFolder := copy(ParamStr(i),3,Length(ParamStr(i))-2);
      end;
  end;

procedure TMainForm.FormDestroy(Sender: TObject);
  begin
    deleteFile(pPath);
    if assigned(settings) then begin
      settings.saveToRegistry;
      settings.Free;
    end;
    if assigned(CapEnum) then CapEnum.Free;
    if assigned(VideoMediaTypes) then VideoMediaTypes.Free;
  end;

procedure TMainForm.TimerTimer(Sender: TObject);
  const sb: Array[0..3] of String = (' B',' KB',' MB',' GB');
  const MiliSecInOneDay = 86400000;
  var txt                 : String;
      position,size       : int64;
      Hour, Min, Sec, MSec: Word;
      b                   : Byte;
  begin
    if CaptureGraph.Active then begin
      with CaptureGraph as IMediaSeeking do GetCurrentPosition(position);
      DecodeTime(position div 10000 / MiliSecInOneDay, Hour, Min, Sec, MSec);
      txt := 'Uptime: ' + Format('%d:%d:%d:%d',[Hour,Min, Sec, MSec]);
    end else txt := '';
    if txt <> '' then txt := txt +' / ';
    size := 1;
    for b := 0 to Length(sb) -1 do
      if transfer <= (size *1024) then begin
        txt := txt + intToStr(transfer div size) +sb[b];
        break;
      end else size := size * 1024;
    StatusBar.Panels[0].Text := txt;
  end;

procedure TMainForm.takeAPicture(path: String);
  var bmp: TBitmap;
  begin
    bmp := TBitmap.Create;
    try
      ImageGrabber.GetBitmap(bmp);
      bmp.Height := bmp.Height +15;
      bmp.Canvas.Font.Size := 9;
      bmp.Canvas.TextOut(5,bmp.Height -14,formatDateTime('dddddd',now) + ', '+
                         formatDateTime('hh:mm:ss',now));
    except
    end;
    bmp.SaveToFile(pPath);
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
      for i := 0 to VideoMediaTypes.Count - 1 do begin
        cmbFormats.Items.Add(VideoMediaTypes.MediaDescription[i]);
        if (cmbCams.Items.Strings[cmbCams.ItemIndex] = settings.cam) and
           (VideoMediaTypes.MediaDescription[i] = settings.format) then
          cmbFormats.ItemIndex := i;
      end;
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

function  TMainForm.setCam(quiet: Boolean): Boolean;
  var PinList: TPinList;
  begin
    Result := True;
    if cmbCams.ItemIndex = -1 then begin
      if not quiet then
        showmessage('You haven''t set a video source!');
      Result := False;
      exit;
    end;
    CaptureGraph.Active := True;
    if VideoSourceFilter.FilterGraph <> nil then begin
      PinList := TPinList.Create(VideoSourceFilter as IBaseFilter);
      if cmbFormats.ItemIndex <> -1 then begin
        with (PinList.First as IAMStreamConfig) do
          SetFormat(VideoMediaTypes.Items[cmbFormats.ItemIndex].AMMediaType^);
      end;
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
      showMessage('The interval is invalid!');
      tmrUpload.Interval := 300 * 1000;
    end;
    tmrUpload.Enabled := True;
    TrayIcon.Hint := 'VideoCap - activ';
    //- save settings -
    settings.cam := cmbCams.Items.Strings[cmbCams.itemIndex];
    settings.format := cmbFormats.Items.Strings[cmbFormats.itemIndex];
    settings.server := edtFTPTarget.Text;
    settings.user := edtFTPUser.Text;
    settings.passw := edtFTPPass.Text;
    settings.interv := tmrUpload.Interval div 1000;
  end;

procedure TMainForm.btnStart2Click(Sender: TObject);
  begin setCam(False); end;

procedure TMainForm.btnStopClick(Sender: TObject);
  begin
    Timer.Enabled := false;
    btnStop.Enabled := false;
    btnStart.Enabled := true;
    CaptureGraph.Stop;
    CaptureGraph.Active := False;
    cmbFormats.Enabled := true;
    cmbCams.Enabled := true;
    TrayIcon.Hint := 'VideoCap - not activ';
    tmrUpload.Enabled := False;
  end;

procedure TMainForm.tmrUploadTimer(Sender: TObject);
  var ind : Integer;
      str : String;
      Host, Folder, User, Pass, Target: String;
  begin
    deleteFile(pPath);
    takeAPicture(pPath);
    try
      if edtFTPUser.Text = '' then User := 'Anonymous'
      else User := edtFTPUser.Text;
      Pass := edtFTPPass.Text;
      str := lowercase(trim(edtFTPTarget.Text));
      if copy(str,0,6) = 'ftp://' then str := copy(str,7,Length(str) -6);
      ind := pos('/',str);
      if ind <> 0 then Host := copy(str,0,ind -1)
      else Host := str;
      if ind <> 0 then
        Folder := copy(str,ind+1,Length(str) -ind -pos('/',strReverse(str)));
      ind := pos('/',strReverse(str));
      Target := copy(str,Length(str) -ind +2, ind+1);
      if not assigned(upload) then begin
        upload := TUploadThread.Create(True);
        upload.OnResult := handleThreadDeath;
      end;
      if copy(strReverse(copyFolder),0,1) <> '\' then
        copyFolder := copyFolder + '\';
      if not uploadActive then begin
        upload.setFTPParams(host,folder,user,pass,pPath,target,copyFolder);
        uploadActive := True;
        if upload.Suspended then upload.Resume
        else upload.execute;
      end;
    except
    end;
  end;

procedure TMainForm.handleThreadDeath(Sender: TObject; success: Boolean;
          Msg: String; size: Cardinal);
  begin
    uploadActive := False;
    if success then transfer := transfer +size;
    StatusBar.Panels[2].Text := formatdateTime('hh:mm:ss',Now) +': ' +Msg;
  end;

procedure TMainForm.hiderTimer(Sender: TObject);
  var i: Integer;
  begin
    if (ParamCount >= 1) then
      for i := 1 to ParamCount do
        if ParamStr(i) = '-h' then begin
          Application.Minimize;
          hider.Enabled := False;
          break;
        end;
  end;

procedure TMainForm.Minimieren2Click(Sender: TObject);
  begin Application.Minimize; end;

procedure TMainForm.Minimieren1Click(Sender: TObject);
  begin Application.Restore; end;

procedure TMainForm.Beenden1Click(Sender: TObject);
  begin Application.Terminate; end;

end.
