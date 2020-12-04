unit HmrcRestSupport;

(*****************************************************************************
*                        HMRC API REST Support Unit                          *
******************************************************************************
*  Support types and values for the HMRC REST Client components              *
*                                                                            *
*  created 24/11/18.                                                         *
*  updated 12/01/19.                                                         *
*  version 1.0.0                                                             *
*                                                                            *
*  original copyright Ian Hamilton 2018/19.                                  *
*****************************************************************************)

interface
(****************************************************************************)
uses
  System.Classes, System.SysUtils, System.UITypes, System.Variants,
  IPPeerClient, REST.Types, REST.Client, REST.Authenticator.OAuth,
  System.JSON;

(****************************************************************************)
const
  REST_ = 'REST';

  csAccessToken   = 'access_token';
  csApJson        = 'application/json';
  csApVnd            = 'application/vnd.hmrc.';
  csAuthorization    = 'Authorization';
  csAuthorize        = 'oauth/authorize';
  csAuthToken        = 'oauth/token';
  csAuthCode         = 'authorization_code';
  csChargeRefNumber  = 'chargeRefNumber';
  csClientId         = 'client_id';
  csClientSecret     = 'client_secret';
  csCode             = 'code';
  csError            = 'Error : ';
  csExpiresIn        = 'expires_in';
  csFormBundleNumber = 'formBundleNumber';
  csFrom             = 'from';
  csGrantType        = 'grant_type';
  csHello            = 'hello';
  csHmrcLogin        = 'HMRC Service Login';
  csIsoDate          = 'YYYYMMDD';
  csLBearer          = 'bearer';
  csLiabilities      = 'liabilities';
  csMessage          = 'message';
  csObligations      = 'obligations';
  csOrgsVat          = 'organisations/vat/';
  csPaymentIndicator = 'paymentIndicator';
  csPayments         = 'payments';
  csProcessingDate   = 'processingDate';
  csReadVat          = 'read:vat';
  csReceiptId        = 'Receipt-Id';
  csRedirectUri      = 'redirect_uri';
  csRefreshToken     = 'refresh_token';
  csResponseType     = 'response_type';
  csReturns          = 'returns';
  csRiteVat          = 'write:vat';
  csScope            = 'scope';
  csStatus           = 'status';
  csTo               = 'to';
  csTokenType        = 'token_type';
  csUBearer          = 'Bearer';
  csWithJson         = '+json';
  csXCorrelationid   = 'X-Correlationid';


  csMsgBadData     = 'The data is either invalid or incomplete';
  csMsgBadPeriod   = 'The VAT Period is invalid';
  csMsgBadResponse = 'HTTP Reponse error.';
  csMsgBadTarget   = 'The target name is invalid.';
  csMsgBadUserId   = 'Invalid User ID found.';
  csMsgDateError   = 'Search date error - the start date must be before the end date.';
  csMsgDateHigh    = 'The start date is too late.';
  csMsgDateLow     = 'The start date is too early.';
  csMsgDateRange   = 'The search date range is too great.';
  csMsgNewToken    = 'Please get a new token.';
  csMsgNoClient    = 'A client id and secret must be supplied.';
  csMsgNoData      = 'No data was supplied for submission.';
  csMsgNoPort      = 'A valid callback port must be supplied.';
  csMsgNoSvrToken  = 'No server token found.';
  csMsgNoTokenFnd  = 'No access token found. PLease get an access token and try again.';
  csMsgNoTokenRtn  = 'No access token returned.';
  csMsgNoUri       = 'Base and callback URLs must be supplied.';
  csMsgNoUserId    = 'No User ID found.';
  csMsgNoAcsToken  = 'There is no access token for this user and scope. ';
  csMsgNoRefresh   = 'Unable to refresh the access token.';
  csMsgNoRfsToken  = 'There is no refresh token for this user and scope.';
  csMsgRefreshErr  = 'Error trying to refresh the access token : ';
  csMsgTestUsrErr  = 'Hello user test error : ';
  csMsgTokenErr    = 'Unknown token error - unable to continue.';
  csMsgTokenExp    = 'The access token for this user and scope has expired.';

  HmrcProdUrl = 'https://api.service.hmrc.gov.uk';
  HmrcTestUrl = 'https://test-api.service.hmrc.gov.uk';

  ERR_NO_ACCESS_TOKEN   = 1101;
  ERR_NO_CALLBACK_PORT  = 1102;
  ERR_NO_CALLBACK_URL   = 1103;
  ERR_NO_CLIENT_ID      = 1104;
  ERR_NO_CLIENT_SECRET  = 1105;
  ERR_NO_DATA           = 1106;
  ERR_NO_REFRESH_TOKEN  = 1107;
  ERR_NO_SERVER_TOKEN   = 1108;
  ERR_NO_TARGET_URL     = 1109;
  ERR_NO_USER_ID        = 1110;

  ERR_TOKEN_EXPIRED     = 1115;

  ERR_DATE_ERROR        = 1121;
  ERR_DATE_LOW          = 1122;
  ERR_DATE_HIGH         = 1123;
  ERR_DATE_RANGE        = 1124;

  ERR_INVALID_USER_ID   = 1131;
  ERR_INVALID_PERIOD    = 1132;
  ERR_INVALID_TARGET    = 1133;
  ERR_INVALID_DATA      = 1134;

  RESULT_NONE  = 0;
  RESULT_OK    = 1;
  RESULT_FAIL  = -1;
  RESULT_ERROR = -3;

(****************************************************************************)
type
  (***************************************************************************
  **            HMRC REST API service authentication modes                  **
  ***************************************************************************)
  THmrcAuthMode = (amNone, amApplication, amUser);

  (***************************************************************************
  **          HMRC REST API service current token status modes              **
  ***************************************************************************)
  THmrcTokenState = (tsNone, tsOK, tsRefresh, tsExpired, tsUpdated);

  (***************************************************************************
  **              HMRC REST API token saving signature                      **
  ***************************************************************************)
  THmrcTokenEvent = procedure(Sender: TObject; const uid, scp, atn, rtn: string; const exp, tmo: TDateTime) of object;

  (***************************************************************************
  **              Relevant scopes as an array of string                     **
  ***************************************************************************)
  TScopeArray = Array of string;

  (***************************************************************************
  **                HMRC REST API user access tokens                        **
  ****************************************************************************
  **  A simple object to hold an access token.                              **
  ***************************************************************************)
  THmrcAccessToken = class
  public
    UID     : string;     // User/ company/ Agent ID
    Scope   : string;     // Authorisation scope
    Access  : string;     // access token
    Refresh : string;     // refresh token
    Expires : TDateTime;  // when it can no longer be refreshed (18 months)  // DateToStr
    TimeOut : TDateTime;  // When the current access token times out (4 hours) // Format[DD-MM-YYYY HH:NN:SS]  DateTimeToStr
    Status  : THmrcTokenState;  // current token state
  end;

  (***************************************************************************
  **  A list to hold access tokens.                                         **
  ***************************************************************************)
  THmrcAccessTokens = class (TList)
  public
    Destructor Destroy; override;
    procedure AddToken(const aUID, aScope, aToken, aRefresh: string; const anExpiry, aTimeOut: TDateTime);
    function  FindToken(const aUID, aScope: string): THmrcAccessToken;
    function  GetAccessToken(const aUID, aScope: string): THmrcAccessToken;
  end;

  (***************************************************************************
  **                   HMRC REST API Client Details                         **
  ****************************************************************************
  **  A simple object to hold the list of application/client details.       **
  ***************************************************************************)
  THmrcClientDetails = class
  private
    FClientId     : string;
    FClientSecret : string;
    FCallbackPort : string;
    FCallbackUrl  : string;
    FServerToken  : string;
    FBaseUrl      : string;
  public
    property ClientId     : string  read FClientId      write FClientId;
    property ClientSecret : string  read FClientSecret  write FClientSecret;
    property CallbackPort : string  read FCallbackPort  write FCallbackPort;
    property CallbackUrl  : string  read FCallbackUrl   write FCallbackUrl;
    property ServerToken  : string  read FServerToken   write FServerToken;
    property BaseUrl      : string  read FBaseUrl       write FBaseUrl;
  end;

(****************************************************************************)
implementation
(****************************************************************************)

{ THmrcAccessTokens }

(*****************************************************************************
*                   HMRC REST API user access tokens                         *
******************************************************************************
*  Clear up.                                                                 *
*****************************************************************************)
destructor THmrcAccessTokens.Destroy;
var
  idx: integer;
  obj: THmrcAccessToken;
begin
  if Count > 0 then
    for idx := Count - 1 downto 0 do
    begin
      obj := THmrcAccessToken(Items[idx]);
      Remove(obj);
      obj.Free;
    end;

  inherited;
end;

(*****************************************************************************
*  Add a new token to the list.                                              *
*****************************************************************************)
procedure THmrcAccessTokens.AddToken(const aUID, aScope, aToken, aRefresh: string; const anExpiry, aTimeOut: TDateTime);
var
  idx: integer;
  dun: boolean;
  obj: THmrcAccessToken;
begin
  dun := false;
  // check whether this combination already exists
  if Count > 0 then
  begin
    for idx := 0 to Count - 1 do
    begin
      obj := THmrcAccessToken(Items[idx]);
      if (AnsiSameText(obj.UID, aUID)) and (AnsiSameText(obj.Scope, aScope)) then
      begin
        dun := true;
        Break;
      end;
    end;
  end;
  // need to add it to the list
  if (not dun) then
  begin
    obj := THmrcAccessToken.Create;
    obj.UID := aUID;
    obj.Scope := aScope;
    Self.Add(obj);
  end;
  obj.Access  := aToken;
  obj.Refresh := aRefresh;
  obj.Expires := anExpiry;
  obj.TimeOut := aTimeOut;

  // chack status
  if (anExpiry < Date) then
    obj.Status := tsExpired
  else if (aTimeOut < Now) then
    obj.Status := tsRefresh
  else
    obj.Status := tsOK;
end;

(*****************************************************************************
*  Add a new token to the list.                                              *
*****************************************************************************)
function THmrcAccessTokens.FindToken(const aUID, aScope: string): THmrcAccessToken;
var
  idx: integer;
  dun: boolean;
  obj: THmrcAccessToken;
begin
  Result := nil;
  dun := false;
  // check whether this combination already exists
  if Count > 0 then
  begin
    for idx := 0 to Count - 1 do
    begin
      obj := THmrcAccessToken(Items[idx]);
      if (AnsiSameText(obj.UID, aUID)) and (AnsiSameText(obj.Scope, aScope)) then
      begin
        dun := true;
        Result := obj;
        Break;
      end;
    end;
  end;
  // need to add it to the list
  if (not dun) then
  begin
    obj := THmrcAccessToken.Create;
    obj.UID := aUID;
    obj.Scope := aScope;
    obj.Status := tsUpdated;
    Self.Add(obj);
    Result := obj;
  end;
end;

(*****************************************************************************
*  Find a token in the list.                                                 *
*****************************************************************************)
function THmrcAccessTokens.GetAccessToken(const aUID, aScope: string): THmrcAccessToken;
var
  idx: integer;
  obj: THmrcAccessToken;
begin
  Result := nil;
  if Count > 0 then
  begin
    for idx := 0 to Count - 1 do
    begin
      obj := THmrcAccessToken(Items[idx]);
      if (AnsiSameText(obj.UID, aUID)) and (AnsiSameText(obj.Scope, aScope)) then
      begin
        Result := obj;
        Break;
      end;
    end;
  end;
end;


end.

