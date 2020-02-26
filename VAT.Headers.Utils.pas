unit VAT.Headers.Utils;
//************************************************//
//            Support for VAT MTD                 //
//             VAT.Headers.Utils                  //
//         provided as is, no warranties          //  
//************************************************//

interface

uses  Winapi.Windows;

type

THMRCMTDUtils = Class
  class function ScreensInfo: string;
  class function getTimeZone: string;
  class function getOSUserName: string;
End;

implementation


uses FMX.Platform, System.SysUtils, FMX.Forms, System.DateUtils, System.StrUtils, System.TimeSpan;

{ THMRCMTDUtils }

Function GetDisplayBits: Integer;
var
  ZeroDC: HDC;
begin
  ZeroDC := GetDC(0);
  Try
    Result := GetDeviceCaps(ZeroDC,BITSPIXEL)*GetDeviceCaps(ZeroDC,PLANES);
  Finally
    ReleaseDC (0,ZeroDC);
  End;
end;


class function THMRCMTDUtils.getOSUserName: string;
Var
  lSize: DWORD;
Begin
  lSize := 1024;
  SetLength(Result, lSize);
  If winapi.Windows.GetUserName(PChar(Result), lSize) Then
    SetLength(Result, lSize - 1)
  Else
    RaiseLastOSError;
end;

class function THMRCMTDUtils.ScreensInfo: string;
Resourcestring
  tpl = 'width=$W&height=$H&scaling-factor=$S&colour-depth=$C';
Var
  ScreenService: IFMXScreenService;
  lScale: Single;

Begin
  Result := tpl.Replace('$W', Screen.Width.ToString).Replace('$H', Screen.Height.ToString)
    .Replace('$C', GetDisplayBits.ToString);

  If TPlatformServices.Current.SupportsPlatformService(IFMXScreenService, IInterface(ScreenService)) Then
  Begin
    Result := Result.Replace('$S', ScreenService.GetScreenScale.ToString);
    ScreenService.GetScreenSize
  End
  Else
  Begin
    Result := Result.Replace('$S', '1');
  End;
end;

class function THMRCMTDUtils.getTimeZone: string;
Var
  retval: TTimeSpan;
Begin
  retval := TTimeZone.Local.GetUtcOffset(Now);
  result := 'UTC' + ifThen(retval.Hours >= 0, '+') + FormatFloat('00', retval.Hours) + ':' +
    FormatFloat('00', retval.Minutes);
End;

end.
