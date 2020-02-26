Unit Systematic.FMX.MacAddress;

//************************************************//
//            Getting MAC Addresses               //
//         Systematic.FMX.MacAddress;             //
//         provided as is, no warranties          //  
//************************************************//
Interface

Uses System.SysUtils, System.Classes, System.NetEncoding;

Function GetMACAddress(ADevice: Integer): String;
{$IF DEFINED(MSWINDOWS)}
//as a short cut this uses the JCL, needs rewriting to be platform independant - i.e. get device list and use GetMacAddress
Function GetAllMacAddresses(const UserPercentEncoding: boolean = False): string;
{$ENDIF}
Function GetLocalComputerName: String;
Function GetOSUserName: String;

Implementation

{$IF DEFINED(MSWINDOWS)}

Uses NB30, Winapi.Windows, jclSysInfo, REST.Utils;
{$ELSE}

Uses Posix.Base, Posix.SysSocket, Posix.NetIf, Posix.NetinetIn, Posix.ArpaInet,
  Posix.SysSysctl;

Type
  u_char = UInt8;
  u_short = UInt16;

  sockaddr_dl = Record
    sdl_len: u_char; // * Total length of sockaddr */
    sdl_family: u_char; // * AF_LINK */
    sdl_index: u_short; // * if != 0, system given index for interface */
    sdl_type: u_char; // * interface type */
    sdl_nlen: u_char; // * interface name length, no trailing 0 reqd. */
    sdl_alen: u_char; // * link level address length */
    sdl_slen: u_char; // * link layer selector length */
    sdl_data: Array [0 .. 11] Of AnsiChar; // * minimum work area, can be larger;
    // contains both if name and ll address */
  End;

  psockaddr_dl = ^sockaddr_dl;

Const
  IFT_ETHER = $6; // if_types.h
{$ENDIF}
{$IF DEFINED(MSWINDOWS)}

Function GetMACAddress(ADevice: Integer): String;
Var
  AdapterList: TLanaEnum;
  Adapter: TAdapterStatus;
  NCB1, NCB2: TNCB;
  Lana: AnsiChar;
Begin
  FillChar(NCB1, SizeOf(NCB1), 0);
  NCB1.ncb_command := Char(NCBENUM);
  NCB1.ncb_buffer := @AdapterList;
  NCB1.ncb_length := SizeOf(AdapterList);
  Netbios(@NCB1);
  If Byte(AdapterList.length) > 0 Then
  Begin
    // AdapterList.lana[] contiene i vari lDevice hardware
    Lana := AdapterList.Lana[ADevice];
    FillChar(NCB2, SizeOf(NCB2), 0);
    NCB2.ncb_command := Char(NCBRESET);
    NCB2.ncb_lana_num := Lana;
    If Netbios(@NCB2) <> Char(NRC_GOODRET) Then
    Begin
      Result := 'mac not found';
      Exit;
    End;
    FillChar(NCB2, SizeOf(NCB2), 0);
    NCB2.ncb_command := Char(NCBASTAT);
    NCB2.ncb_lana_num := Lana;
    NCB2.ncb_callname := '*';
    FillChar(Adapter, SizeOf(Adapter), 0);
    NCB2.ncb_buffer := @Adapter;
    NCB2.ncb_length := SizeOf(Adapter);
    If Netbios(@NCB2) <> Char(NRC_GOODRET) Then
    Begin
      Result := 'mac not found';
      Exit;
    End;
    Result := IntToHex(Byte(Adapter.adapter_address[0]), 2) + '-' + IntToHex(Byte(Adapter.adapter_address[1]), 2) + '-'
      + IntToHex(Byte(Adapter.adapter_address[2]), 2) + '-' + IntToHex(Byte(Adapter.adapter_address[3]), 2) + '-' +
      IntToHex(Byte(Adapter.adapter_address[4]), 2) + '-' + IntToHex(Byte(Adapter.adapter_address[5]), 2);
  End
  Else
    Result := 'mac not found';
End;

{$ELSE}
Function getifaddrs(Var ifap: pifaddrs): Integer; Cdecl; External libc Name _PU + 'getifaddrs';
{$EXTERNALSYM getifaddrs}
Procedure freeifaddrs(ifp: pifaddrs); Cdecl; External libc Name _PU + 'freeifaddrs';
{$EXTERNALSYM freeifaddrs}

Function GetMACAddress(ADevice: Integer): String;
Var
  ifap, Next: pifaddrs;
  sdp: psockaddr_dl;
  ip: AnsiString;
  MacAddr: Array [0 .. 5] Of Byte;
  lDevice: Integer;
Begin
  lDevice := 0;
  Try
    If getifaddrs(ifap) <> 0 Then
      RaiseLastOSError;
    Try
      SetLength(ip, INET6_ADDRSTRLEN);
      Next := ifap;
      While Next <> Nil Do
      Begin
        Case Next.ifa_addr.sa_family Of
          AF_LINK:
            Begin
              sdp := psockaddr_dl(Next.ifa_addr);
              If sdp.sdl_type = IFT_ETHER Then
              Begin
                Move(Pointer(PAnsiChar(@sdp^.sdl_data[0]) + sdp.sdl_nlen)^, MacAddr, 6);
                If (ADevice = lDevice) Then
                Begin
                  Result := IntToHex(MacAddr[0], 2) + '-' + IntToHex(MacAddr[1], 2) + '-' + IntToHex(MacAddr[2], 2) +
                    '-' + IntToHex(MacAddr[3], 2) + '-' + IntToHex(MacAddr[4], 2) + '-' + IntToHex(MacAddr[5], 2);
                End;
                lDevice := lDevice + 1;
              End;
            End;
        End;
        Next := Next.ifa_next;
      End;
    Finally
      freeifaddrs(ifap);
    End;
  Except
    On E: Exception Do
      Result := ''; // E.ClassName + ': ' + E.Message;
  End;
  // se non ha trovato nulla
End;
{$ENDIF}

{$IF DEFINED(MSWINDOWS)}
Function GetAllMacAddresses(const UserPercentEncoding: boolean = False): string;
var TS: TStringList;
  I: Integer;
begin
  Result := '';
  TS := TStringList.Create;
  try
    jclSysInfo.GetMacAddresses('', TS);
    for I := 0 to TS.Count - 1 do
     begin
       if UserPercentEncoding then
          Result := Result +URIEncode(TS[I].Replace('-', ':', [rfReplaceAll]).ToLower) + ','
       else
       begin
         Result := Result + TS[I].Replace('-', ':', [rfReplaceAll]).ToLower + ',';
       end;
     end;
  finally
    TS.Free;
  end;

  Result := Result.TrimRight([',']);
end;
{$ENDIF}

Function GetLocalComputerName: String;
Var
{$IFDEF MSWINDOWS}
  c1: DWORD;
  arrCh: Array [0 .. MAX_COMPUTERNAME_LENGTH] Of Char;
{$ENDIF}
{$IFDEF POSIX}
  len: size_t;
  p: PAnsiChar;
  res: Integer;
{$ENDIF}
Begin
{$IFDEF MSWINDOWS}
  c1 := MAX_COMPUTERNAME_LENGTH + 1;
  If GetComputerName(arrCh, c1) Then
    SetString(Result, arrCh, c1)
  Else
    Result := '';
{$ENDIF}
{$IFDEF POSIX}
  Result := '';
  res := sysctlbyname('kern.hostname', Nil, @len, Nil, 0);
  If (res = 0) And (len > 0) Then
  Begin
    GetMem(p, len);
    Try
      res := sysctlbyname('kern.hostname', p, @len, Nil, 0);
      If res = 0 Then
        Result := String(AnsiString(p));
    Finally
      FreeMem(p);
    End;
  End;
{$ENDIF}
End;

Function GetOSUserName: String;
{$IFDEF MSWINDOWS}
Var
  lSize: DWORD;
{$ENDIF}
Begin
{$IFDEF MACOS}
  Result := TNSString.Wrap(NSUserName).UTF8String;
{$ENDIF}
{$IFDEF MSWINDOWS}
  lSize := 1024;
  SetLength(Result, lSize);
  If GetUserName(PChar(Result), lSize) Then
    SetLength(Result, lSize - 1)
  Else
    RaiseLastOSError;
{$ENDIF} End;

End.
