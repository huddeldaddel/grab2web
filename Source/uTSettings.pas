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

unit uTSettings;

interface

uses Registry;

type

  TSettings = class(TObject)
  public
    cam   : String;
    format: String;
    server: String;
    user  : String;
    passw : String;
    interv: Integer;
    constructor Create();
    procedure loadFromRegistry();
    procedure saveToRegistry();
  end;

implementation

const REG_PATH = 'SOFTWARE\grab2web';

constructor TSettings.Create();
  begin
    inherited;
    cam   := '';
    format:= '';
    server:= 'server.com/folder/picture.jpg';
    user  := 'Anonymous';
    passw := '*******';                                                         // ;)
    interv:= 300;                                                               // 5 minutes
  end;

procedure TSettings.loadFromRegistry();
  var reg: TRegistry;
  begin
    reg := TRegistry.Create;
    try
      reg.OpenKey(REG_PATH, True);
      if reg.ValueExists('cam') then cam := reg.ReadString('cam');
      if reg.ValueExists('format') then format := reg.ReadString('format');
      if reg.ValueExists('server') then server := reg.ReadString('server');
      if reg.ValueExists('user') then user := reg.ReadString('user');
      if reg.ValueExists('passw') then passw := reg.ReadString('passw');
      if reg.ValueExists('interv') then interv := reg.ReadInteger('interv');
    finally
      reg.CloseKey;
      reg.Free;
    end;
  end;

procedure TSettings.saveToRegistry();
  var reg: TRegistry;
  begin
    reg := TRegistry.Create;
    try
      reg.OpenKey(REG_PATH, True);
      reg.WriteString('cam',cam);
      reg.WriteString('format',format);
      reg.WriteString('server',server);
      reg.WriteString('user',user);
      reg.WriteString('passw',passw);
      reg.WriteInteger('interv',interv);
    finally
      reg.CloseKey;
      reg.Free;
    end;
  end;

end.
