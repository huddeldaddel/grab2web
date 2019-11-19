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

unit uTUploadThread;

interface

uses

  Classes, IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdFTP,
  SysUtils, Jpeg, JclFileUtils, Graphics, Windows;

type

  TOnResult = procedure(Sender:TObject; success:Boolean; Msg: String;
              size: Cardinal) of object;

  TUploadThread = class(TThread)
  private
    ftp: TIdFTP;
    pFolder, pSource, pTarget, pCopyF: String;
    eOnResult: TOnResult;
    function  convertFileFormat(sFile,tFile: String): Boolean;
  published
    property OnResult: TOnResult read eOnResult write eOnResult;
  public
    constructor Create(CreateSuspended: Boolean);
    destructor  Destroy; override;
    procedure setFTPParams(Host,Folder,User,Pass,Source,Target,copyF: String);
    procedure execute(); override;
  end;

implementation

constructor TUploadThread.Create(CreateSuspended: Boolean);
  begin
    inherited Create(CreateSuspended);
    ftp := TIdFTP.Create(nil);
  end;

destructor  TUploadThread.Destroy;
  begin
    if assigned(ftp) then begin
      if ftp.Connected then ftp.Disconnect;
      FreeAndNil(ftp);
    end;
    inherited;
  end;

function  TUploadThread.convertFileFormat(sFile,tFile: String): Boolean;
  var Bitmap: Graphics.TBitmap;
      JpegImg: TJpegImage;
  begin
    Result := True;
    Bitmap := Graphics.TBitmap.Create;
    try
      Bitmap.LoadFromFile(sFile) ;
      JpegImg := TJpegImage.Create;
      try
        JpegImg.Assign(Bitmap) ;
        JpegImg.SaveToFile(tFile) ;
      except Result := False;
      end;
      JpegImg.Free();
    finally Bitmap.Free();
    end;
  end;

procedure TUploadThread.setFTPParams(Host, Folder, User, Pass, Source,
          Target, copyF: String);
  begin
    ftp.Host := Host;
    ftp.Username := User;
    ftp.Password := Pass;
    pFolder := Folder;
    pSource := Source;
    pTarget := Target;
    pCopyF := copyF;
  end;

procedure TUploadThread.execute();
  var JpgFil: String;
      Messag: String;
      Result: Boolean;
      tmpFil: String;
  begin
    Result := False;
    JpgFil := pSource +'.jpg';
    try
      if not convertFileFormat(pSource,JpgFil) then begin
        Messag := 'Konvertierung der Grafik fehlgeschlagen';
        exit;
      end;
      Messag := 'Upload fehlgeschlagen';
      ftp.Connect();
      if not ftp.Connected then begin
        Messag := 'Verbindung konnte nicht hergestellt werden';
        exit;
      end;
      try    ftp.ChangeDir(pFolder);
      except
        Messag := 'Verzeichnis-Wechsel fehlgeschlagen';
        exit;
      end;
      try    ftp.Delete(pTarget);
      except
      end;
      ftp.Put(JpgFil,pTarget,False);
      Messag := 'Upload erfolgreich';
      Result := True;
      tmpFil := formatDateTime('yyyymmdd',now)+'_'+formatDateTime('hhmmss',now);
      tmpFil := pCopyF +tmpFil +'.jpg';
      if pCopyF <> '' then copyFile(PChar(JpgFil),PChar(tmpFil),True);
    finally
      if ftp.Connected then ftp.Disconnect;
      if assigned(eOnResult) then
        eOnResult(self,Result,Messag,FileGetSize(JpgFil));
      deleteFile(PChar(JpgFil));
    end;
  end;

end.
