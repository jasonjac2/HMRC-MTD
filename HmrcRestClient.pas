Unit HmrcRestClient;

(* ****************************************************************************
  *                         HMRC API REST Client Unit                          *
  ******************************************************************************
  *  This unit contains new class definitions which inherit from TRESTClient   *
  *  and add the necessary data and processes to connect to the HMRC API. It   *
  *  was originally developed as a part of the UK-DevGroup collaborative       *
  *  attempt to access the HMRC API using OAuth2 in Nov/Dec 2018.              *
  *                                                                            *
  *  It was originally developed to work with the v1.0 beta version of the     *
  *  API and HMRC warn that there are likely to be breaking changes during     *
  *  the development of their API services, so you should ensure that you are  *
  *  using an up to date version of these components.                          *
  *                                                                            *
  *  There are 3 classes of authorisation: none, application and user. These   *
  *  seem to be a standard set for REST with JSON over HTTP, which is what     *
  *  this is about. The user based process uses an OAuth2 authorisation to get *
  *  an access token from a target url, which will be on the gov/hmrc site.    *
  *  All of the API services appear to require OAuth2, except for the create   *
  *  (test) user processess, which require application authorisation and 2 of  *
  *  the "hello" connection tests. These are all handled in the                *
  *  THmrcTestClient class.                                                    *
  *                                                                            *
  *  HMRC have added an extra level to the process as "scope" and everything   *
  *  happens within a given scope. Access tokens relate to a particular scope  *
  *  and must be both aquired and used within that scope. Each API resource /  *
  *  endpoint has a scope assigned, which must be used in all calls to it.     *
  *                                                                            *
  *  The connection details and application/client key/id and secret are       *
  *  supplied by the application, being stored and loaded as appropriate.      *
  *                                                                            *
  *  The headers required for requests and submissions to the HMRC API are     *
  *  listed on the HMRC website, which, at the time this was created, was here *
  *
  *  They depend to a certain extent on the type of application, so the        *
  *  programmer is responsible for ensuring that the correct values are used   *
  *  and for checking that the requirements have not changed over time.        *
  *                                                                            *
  *  All calls are made in the name of a "user" on the HMRC system. They have  *
  *  a UserId as a string, which uniquely identifies them to HMRC. The classes *
  *  here have a single value, FUID, to hold this and the application will     *
  *  pass the appropriate values. For the NI API, this will be the NINo, for   *
  *  VAT it will be the VRN, etc.                                              *
  *                                                                            *
  *  Valid calls which return no data are returned with a 404 NOT FOUND error. *
  *  Why is known only to HMRC, but it means that if 404 is returned, it is    *
  *  necessary to check the text that goes with it, to see whether there is    *
  *  actually a problem, or just no data.                                      *
  *                                                                            *
  *  This was written in 10.2.3 (Tokyo) and should work in some recent         *
  *  earlier versions. It uses units from the REST set which should be found   *
  *  in C:\Program Files (x86)\Embarcadero\Studio\19.0\source\data\rest or     *
  *  whatever the corresponding location would be on the machine used to       *
  *  run this code.                                                            *
  *                                                                            *
  *  Anyone is welcome to bend this for their own purposes, but no liability   *
  *  can be accepted by the author for any loss of or damage to hardware,      *
  *  software, data, finance, income or reputation resulting from the use of   *
  *  this code, howsoever caused. In any event, maximum liability shall not    *
  *  exceed the amount paid by the user for the code.                          *
  *                                                                            *
  *  created  21/11/18 from the initial test case.                             *
  *                                                                            *
  *  version  0.8.1 beta  released 12/01/19    to include the api versions     *
  *                                            available at that time.         *
  *                                                                            *
  *  original copyright Ian Hamilton 2018/19.                                  *
  *  License : GPL                                                             *
  *                                                                            *
  **************************************************************************** *)

Interface

(* ************************************************************************** *)
Uses
  System.Classes, System.SysUtils, System.UITypes, System.Variants,
  IPPeerClient, REST.Types, REST.Client, REST.Authenticator.OAuth,
  System.JSON,
  HmrcRestSupport;

(* ************************************************************************** *)
Type
  (* **************************************************************************
    **          Base REST Client for the HMRC REST API service                **
    **                                                                        **
    **  This handles authentication and connections, but should not be used   **
    **  directly.                                                             **
    **                                                                        **
    **  In general, the relevant User Id and scope should be set before       **
    **  making any calls to the API.                                          **
    **  Headers can be added one at a time using the AddaHeader method, or    **
    **  supplied as a list using SetHeaderList.                               **
    **  By default, IzTest is set to false, so it will automatically target   **
    **  the LIVE API service. If using it for testing please remember to set  **
    **  IzTest to true to target the TEST API.                                **
    **                                                                        **
    **  All methods will return a result as an integer. This can have 1 of 4  **
    **  values:                                                               **
    **    0 : Nothing - this should not be returned                           **
    **    1 : Success - get the JSON Value returned by the API from LastValue **
    **    2 : Failure - get the error messages from LastError and LastMsg     **
    **    3 : Exception - get the exception message from LastError            **
    **                                                                        **
    ************************************************************************** *)
  THMRCRestClient = Class(TRESTClient)
  Strict private
   class var FResetCount: Integer;
  Private
    FStoreFolder: String;
    // PROPERTY METHODS SECTION
    Function GetLastCode: integer;
    Function GetLastError: String;
    Function GetLastMsg: String;
    Function GetLastValue: TJSONValue;
    Procedure SetApiVersion(Const Value: String);
    Procedure SetAuthMode(Const Value: THmrcAuthMode);
    Procedure SetAuthScope(Const Value: String);
    Procedure SetCallbackUrl(Const Value: String);
    Procedure SetIzTest(Const Value: boolean);
    Procedure SetUID(Const Value: String); // virtual;
  Protected
    FApiVersion: String; // the version of the api to target
    FAuthMode: THmrcAuthMode; // the level of authentication required
    FAuthScope: String; // the scope of the authorisation
    FBaseResource: String; // base element of the service resource
    FCallbackPort: String; // call back port for authentication process
    FCallbackUrl: String; // call back url for authentication process
    FClientId: String; // application/client key for login
    FClientSecret: String; // application/client secret for login
    FIzTest: boolean; // test or production api
    FLastCode: integer; // the response code of the last http call or error value
    FLastError: String; // the last error/failure message
    FLastMsg: String; // the last http response status text
    FLastValue: TJSONValue; // the last api response as a json value
    FOwnsHeaders: boolean; // does it own the header list, it will need to free the list if true
    FServerToken: String; // token for application login
    FTokenState: THmrcTokenState; // status of current hmrc access tokens
    FUID: String; // unique ID for this user/customer for this service
    LAccessTokens: THmrcAccessTokens; // a list of user access tokens from the authentication process
    LHeaderList: TStringList; // a list for the header values required by hmrc
    LScopeList: TScopeArray; // list of relevant scopes
    OAccessToken: THmrcAccessToken; // the current access token
    ORequest: TRESTRequest; // Rest client component

    // NEW ACCESS TOKEN (NAT) SECTION
    Function NAT_BildAuthUrl: String; // build the OAuth2 login url
    Function NAT_CheckReady: boolean; // check the initial values have been loaded/set
    Procedure NAT_SetOAuth2; // set authentication parameters to get a new access token
    Procedure NAT_TryForToken(Const aUrl: String; Var DoCloseWebView: boolean);
    // a TOAuth2WebFormRedirectEvent to handle part 2 to get the access token
    Procedure NAT_WebFormClose(Sender: TObject; Var Action: TCloseAction);
    // the WebForm OnClose event - close the login form

    // REFRESH ACCESS TOKEN (RAT) SECTION
    Function RAT_RefreshToken: integer; // get a new access token using the current refresh token
    Procedure RAT_SetOAuth2; // set authentication parameters to refresh an access token

    // REQUEST (REQ) SECTION
    Function REQ_BildAccept: String; // build the accept parameter string
    Function REQ_CheckToken: boolean; // check whether there is a token and whether it is current. Try to refresh.
    Procedure REQ_ClearLast; // clear the last response values
    Function REQ_DateFormat(Const Value: TDateTime): String; // convert date to HMRC compatible date string
    Procedure REQ_Reset; // reset request to defaults
    Procedure REQ_LoadHeaders; // RPW added 21/02/2020
  Public
    OnTokenChange: THmrcTokenEvent; // pointer to method to save / update saved token
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;

    Procedure AddaHeader(Const aName, aValue: String; Const NoEncode: boolean = False);
    Procedure RemoveaHeader(Const aName: String);
    Procedure AddaToken(Const uid, scp, atn, rtn: String; Const exp, tmo: TDateTime); // add a token to the tokens list
    Function ListScopes: String; // return list of relevant scopes as a comma separated list
    Function NewAccessToken: boolean; // (NAT) try to login and authenticate with a user
    Procedure SetHeaderList(Const Value: TStringList; OwnsList: boolean = true); // set a list of header values
    Function SetHmrcID(Const Value: String): integer; Virtual; // set HMRC "User" ID

    class procedure InitialiseClassVars;
    Property LastCode: integer Read GetLastCode;
    Property LastError: String Read GetLastError;
    Property LastMsg: String Read GetLastMsg;
    Property LastValue: TJSONValue Read GetLastValue;
  Published
    Property ApiVersion: String Read FApiVersion Write SetApiVersion;
    Property AuthMode: THmrcAuthMode Read FAuthMode Write SetAuthMode;
    Property AuthScope: String Read FAuthScope Write SetAuthScope;
    Property BaseResource: String Read FBaseResource Write FBaseResource;
    Property CallbackPort: String Read FCallbackPort Write FCallbackPort;
    Property CallbackUrl: String Read FCallbackUrl Write SetCallbackUrl;
    Property ClientId: String Read FClientId Write FClientId;
    Property ClientSecret: String Read FClientSecret Write FClientSecret;
    Property IzTest: boolean Read FIzTest Write SetIzTest;
    Property ServerToken: String Read FServerToken Write FServerToken;
    Property uid: String Read FUID Write SetUID;
    // RPW
    Property StoreFolder: String Read FStoreFolder Write FStoreFolder;
    Property HeaderList: TStringList Read LHeaderList;
  End;

  (* **************************************************************************
    **             Test REST Client for the HMRC REST API service             **
    **                                                                        **
    **  This handles the "hello" test endpoints provided by the API service   **
    **  and also sets up test users.                                          **
    **  At some point the API may stop supporting some or all of these.       **
    **  API Version 1.0                                                       **
    **                                                                        **
    **  The user id is the value of "userId" for the test user.               **
    ************************************************************************** *)
  THmrcTestClient = Class(THMRCRestClient)
  Private
  Protected
    // NEW USER (NUS) SECTION
    Function NUS_CheckReady: boolean; // check the initial values have been loaded/set
  Public
    Constructor Create(AOwner: TComponent); Override;
    Function AddAgent: integer; // call the user api to add a new user as an agent
    Function AddCompany: integer; // call the user api to add a new user as a business
    Function AddPerson: integer; // call the user api to add a new user as an individual
    Function TestHelloApplication: String; // call the hello application end point
    Function TestHelloUser: String; // call the hello user end point
    Function TestHelloWorld: String; // call the hello world end point
    Function TestFraudHeaders: integer; // call to test the fraud headers
  End;

  (* **************************************************************************
    **            NI REST Client for the HMRC REST API service                **
    **                                                                        **
    **  This handles NI services provided by the API service.                 **
    **                                                                        **
    **  The user id is the UTR.  (10 digits)                                  **
    **  Resource = /national-insurance/sa/{utr}/annual-summary/{taxYear}      **
    **  Tax year in the format YYYY-YY                                        **
    ************************************************************************** *)
  THmrcNIClient = Class(THMRCRestClient)
  Private
  Protected
  Public
    Constructor Create(AOwner: TComponent); Override;
  End;

  (* **************************************************************************
    **          PAYE REST Client for the HMRC REST API service                **
    **                                                                        **
    **  This handles PAYE services provided by the API service.               **
    **                                                                        **
    **  The user id is the UTR.  (10 digits)                                  **
    **  Resource = /national-insurance/sa/{utr}/annual-summary/{taxYear}      **
    **  Tax year in the format YYYY-YY                                        **
    ************************************************************************** *)
  THmrcPAYEClient = Class(THMRCRestClient)
  Private
  Protected
  Public
    Constructor Create(AOwner: TComponent); Override;
  End;

  (* **************************************************************************
    **            SA REST Client for the HMRC REST API service                **
    **                                                                        **
    **  This handles Self Assessment services provided by the API service.    **
    **                                                                        **
    **  The user id is the UTR.  (10 digits)                                  **
    **  Resource = /national-insurance/sa/{utr}/annual-summary/{taxYear}      **
    **  Tax year in the format YYYY-YY                                        **
    ************************************************************************** *)
  THmrcSAClient = Class(THMRCRestClient)
  Private
  Protected
  Public
    Constructor Create(AOwner: TComponent); Override;
  End;

  (* **************************************************************************
    **           VAT REST Client for the HMRC REST API service                **
    **                                                                        **
    **  This handles VAT services provided by the API service.                **
    **                                                                        **
    **  The user id is the VRN.                                               **
    **  Search dates in the format YYYY-MM-DD                                 **
    **  Base resource = organisations/vat/{VRN}/                              **
    **  API Version 1.0                                                       **
    **                                                                        **
    **  There are 5 end points, 4 GET and 1 POST.                             **
    **    Liabilities - GET - (Date From + Date To)                           **
    **    Obligations - GET - (Date From + Date To)                           **
    **    Payments - GET - (Date From + Date To)                              **
    **    Returns - GET - (Period ID)                                         **
    **    SubmitReturns - POST - (List of values)                             **
    **                                                                        **
    **  There are some basic sanity checks run on the parameters supplied for **
    **  the GET calls and on the data to be submitted. Other checks are       **
    **  performed by HMRC, which may cause the call to fail.                  **
    **                                                                        **
    **  The calls to Liabilities, Obligations and Payments are identical,     **
    **  except for the final part of the url. These calls are handled by the  **
    **  SearchLOP method, which accepts the name as a parameter, along with   **
    **  the start and end dates for the search.                               **
    **                                                                        **
    **  The Returns call takes a single VAT period id as a Resource Suffix.   **
    **                                                                        **
    **  The Submit Returns method takes a vat period, a list of values and a  **
    **  finalised (true/false) value. If successful it will return the        **
    **  receipt/confirmation details in a list.                               **
    **                                                                        **
    **  According to HMRC documentation, all apps must access the Obligations **
    **  and SubmitReturns end points. The others are optional.                **
    **                                                                        **
    ************************************************************************** *)
  THmrcVATClient = Class(THMRCRestClient)
  Private
  Protected
    FDateFrom: String; // start date for search
    FDateTo: String; // end date for search

    Function API_SearchLP(Const aType: String; Const FromDate, ToDate: TDateTime): integer;
    // search liabilities / obligations / payments
    Function PRM_CheckDates(Const dtFrom, dtTo: TDateTime): boolean; // basic checks on dates supplied
    Function PRM_CheckPeriod(Const Value: String): boolean; // basic checks on period format
    Function PRM_CheckValues(Const Values: TStringList): boolean; // check the list of values for submission
  Public
    Constructor Create(AOwner: TComponent); Override;

    Function GetLiabilities(Const FromDate, ToDate: TDateTime): integer; // search liabilities for a date range
    Function GetObligations(Const FromDate, ToDate: TDateTime; aStatus: String = ''): integer;
    // search obligations for a date range
    Function GetPayments(Const FromDate, ToDate: TDateTime): integer; // search payments for a date range
    Function GetReturn(Const aPeriod: String; Var ACorrelationId: String): integer;
    Function SubmitReturn(Const aPeriod: String; Const Values: TStringList; Const IzFinal: boolean; Var Confirm: String)
      : integer; // submit a return

    Function SetHmrcID(Const Value: String): integer; Override; // override to apply some kind of validation

  End;

Procedure Register;

(* ************************************************************************** *)
Implementation

(* ************************************************************************** *)
Uses
  REST.Utils,
  FMX.Dialogs,
  System.IOUtils,
  Systematic.OAuth.WebForm.FMX;
// VCL.Dialogs, REST.Authenticator.OAuth.WebForm.Win;

Procedure Register;
Begin
  RegisterComponents('HmrcRestClient', [THmrcTestClient]);
  RegisterComponents('HmrcRestClient', [THmrcVATClient]);
End;

(* ****************************************************************************
  *                           HMRC REST CLIENT                                 *
  ******************************************************************************
  *                             INIT SECTION                                   *
  ******************************************************************************
  *  Init.                                                                     *
  **************************************************************************** *)
Constructor THMRCRestClient.Create(AOwner: TComponent);
Begin
  Inherited;

  ContentType := csApJson;
  FApiVersion := '1.0';
  FAuthMode := amNone;
  FAuthScope := '';
  FBaseResource := '';
  FClientId := '';
  FClientSecret := '';
  BaseUrl := HmrcProdUrl;
  FCallbackUrl := '';
  FCallbackPort := '';
  FIzTest := False;
  FOwnsHeaders := true;
  FServerToken := '';
  FTokenState := tsNone;
  FUID := '';

  REQ_ClearLast;

  OnTokenChange := Nil;

  Setlength(LScopeList, 0);

  // The base class has an FAuthenticator defined as a TCustomAuthenticator
  Authenticator := TOAuth2Authenticator.Create(Self);
  LAccessTokens := THmrcAccessTokens.Create;
  OAccessToken := Nil;
  LHeaderList := TStringList.Create;

  ORequest := TRESTRequest.Create(Nil);
  ORequest.Client := Self;
  ORequest.Accept := REQ_BildAccept;
  ContentType := csApJson;
End;

(* ****************************************************************************
  *  Free request.                                                             *
  **************************************************************************** *)
Destructor THMRCRestClient.Destroy;
Begin
  ORequest.DisposeOf;
  If (Assigned(LAccessTokens)) Then
    LAccessTokens.Free;
  If (Assigned(LHeaderList)) And (FOwnsHeaders) Then
    LHeaderList.Free;

  Inherited;
End;

(* ****************************************************************************
  *                       PUBLIC METHODS SECTION                               *
  ******************************************************************************
  *  Add a name and value to the headers list.                                 *
  **************************************************************************** *)
Procedure THMRCRestClient.AddaHeader(Const aName, aValue: String; Const NoEncode: boolean = False);
Const
  _dont_encode: Array [boolean] Of String = ('encode', 'noencode');
Begin
  LHeaderList.Add(aName + '|' + aValue + '|' + _dont_encode[NoEncode]);
End;

(* ****************************************************************************
  *  Add a new token to the tokens list.                                       *
  **************************************************************************** *)
Procedure THMRCRestClient.AddaToken(Const uid, scp, atn, rtn: String; Const exp, tmo: TDateTime);
Begin
  LAccessTokens.AddToken(uid, scp, atn, rtn, exp, tmo);
End;

(* ****************************************************************************
  *  Return the list of relevant scopes.                                       *
  **************************************************************************** *)
Function THMRCRestClient.ListScopes: String;
Var
  idx: integer;
Begin
  Result := '';
  If (Length(LScopeList) > 0) Then
    For idx := 0 To Length(LScopeList) - 1 Do
    Begin
      If (idx > 0) Then
        Result := Result + ',';
      Result := Result + LScopeList[idx];
    End;
End;

(* ****************************************************************************
  *  Set User ID for HMRC user login.                                          *
  **************************************************************************** *)
Function THMRCRestClient.SetHmrcID(Const Value: String): integer;
Begin
  REQ_ClearLast;
  If (Value <> '') Then
  Begin
    uid := Value;
    Result := RESULT_OK
  End
  Else
  Begin
    FLastCode := ERR_NO_USER_ID;
    FLastError := csMsgNoUserId;
    Result := RESULT_FAIL;
  End;
End;

(* ****************************************************************************
  *                     NEW ACCESS TOKEN (NAT) SECTION                         *
  ******************************************************************************
  *  Build the login part of the initial url for authentication.               *
  **************************************************************************** *)
Function THMRCRestClient.NAT_BildAuthUrl: String;
Begin
  Result := BaseUrl + csAuthorize;
  Result := Result + '?' + csClientId + '=' + FClientId;
  Result := Result + '&' + csRedirectUri + '=' + URIEncode(FCallbackUrl);
  Result := Result + '&' + csResponseType + '=' + csCode;
  Result := Result + '&' + csScope + '=' + FAuthScope;
End;

(* ****************************************************************************
  *  Check whether any required key/secret and urls are set.                   *
  **************************************************************************** *)
Function THMRCRestClient.NAT_CheckReady: boolean;
Begin
  Result := False;
  If (FClientId = '') Then
  Begin
    FLastCode := ERR_NO_CLIENT_ID;
    FLastError := csMsgNoClient;
  End
  Else If (FClientSecret = '') Then
  Begin
    FLastCode := ERR_NO_CLIENT_SECRET;
    FLastError := csMsgNoClient;
  End
  Else If (BaseUrl = '') Then
  Begin
    FLastCode := ERR_NO_TARGET_URL;
    FLastError := csMsgNoUri;
  End
  Else If (FCallbackUrl = '') Then
  Begin
    FLastCode := ERR_NO_CALLBACK_URL;
    FLastError := csMsgNoUri;
  End
  Else If (FCallbackPort = '') Or (StrToIntDef(FCallbackPort, 0) = 0) Then
  Begin
    FLastCode := ERR_NO_CALLBACK_PORT;
    FLastError := csMsgNoPort;
  End
  Else
  Begin
    Result := true;
  End;
End;

(* ****************************************************************************
  *  Set OAuth2 params for HMRC user login.                                    *
  **************************************************************************** *)
Procedure THMRCRestClient.NAT_SetOAuth2;
Begin
  (Authenticator As TOAuth2Authenticator).AccessToken := '';
  (Authenticator As TOAuth2Authenticator).RefreshToken := '';
  (Authenticator As TOAuth2Authenticator).TokenType := TOAuth2TokenType.ttBEARER;
  (Authenticator As TOAuth2Authenticator).ResponseType := TOAuth2ResponseType.rtTOKEN;
  (Authenticator As TOAuth2Authenticator).AccessTokenParamName := csAccessToken;
  (Authenticator As TOAuth2Authenticator).ClientId := FClientId;
  (Authenticator As TOAuth2Authenticator).ClientSecret := FClientSecret;
  (Authenticator As TOAuth2Authenticator).Scope := FAuthScope;
  (Authenticator As TOAuth2Authenticator).AuthorizationEndpoint := BaseUrl + csAuthToken;
  (Authenticator As TOAuth2Authenticator).RedirectionEndpoint := FCallbackUrl;
End;

(* ****************************************************************************
  *  Got a code, so now change that for an access token.                       *
  **************************************************************************** *)
Procedure THMRCRestClient.NAT_TryForToken(Const aUrl: String; Var DoCloseWebView: boolean);
Var
  lvPos: integer;
  lvCode: String;
  lvToken: String;
Begin
  lvCode := '';
  lvToken := '';

  // look for the parameter in the response url
  lvPos := Pos('code=', aUrl);

  If (lvPos > 0) Then
  Begin
    lvCode := Copy(aUrl, lvPos + 5, Length(aUrl));
    If (Pos('&', lvCode) > 0) Then
    Begin
      lvCode := Copy(lvCode, 1, Pos('&', lvCode) - 1);
    End;
    If (lvCode = '') Then
      Exit;

    // so it will close the login form
    DoCloseWebView := true;
    // clear the request
    ORequest.ResetToDefaults;
    ORequest.Client := Self;
    ORequest.Accept := REQ_BildAccept; // was set in create event, but has just been cleared
    // check and initialise the authenticator
    If (Not Assigned(Authenticator)) Then
      Authenticator := TOAuth2Authenticator.Create(Self);
    NAT_SetOAuth2;
    (Authenticator As TOAuth2Authenticator).AuthCode := lvCode;

    // now rebuild the request to get the access token
    ORequest.Method := TRESTRequestMethod.rmPOST;
    ORequest.Resource := csAuthToken;
    ORequest.Params.AddItem(csGrantType, csAuthCode, TRESTRequestParameterKind.pkGETorPOST);
    ORequest.Params.AddItem(csCode, URIEncode(lvCode), TRESTRequestParameterKind.pkGETorPOST);
    ORequest.Params.AddItem(csClientId, FClientId, TRESTRequestParameterKind.pkGETorPOST);
    ORequest.Params.AddItem(csClientSecret, FClientSecret, TRESTRequestParameterKind.pkGETorPOST);
    ORequest.Params.AddItem(csRedirectUri, FCallbackUrl, TRESTRequestParameterKind.pkGETorPOST);

    ORequest.Execute;

    // see what happened
    If (ORequest.Response.Status.Success) Then
    Begin
      // lvJson := ORequest.Response.JSONValue;
      If ORequest.Response.GetSimpleValue(csAccessToken, lvToken) Then
      Begin
        // check it has an access token object
        If (Not Assigned(OAccessToken)) Then
          OAccessToken := LAccessTokens.FindToken(FUID, FAuthScope);
        If (OAccessToken.Access <> lvToken) Then
        Begin
          OAccessToken.Access := lvToken; // new access token
          If ORequest.Response.GetSimpleValue(csExpiresIn, lvToken) Then
            // during testing the expiry time was always 14400 - which is 4 hours in seconds. 86400 seconds in a day.
            OAccessToken.TimeOut := Now + (StrToIntDef(lvToken, 14400) / 86400)
          Else
            OAccessToken.TimeOut := Now + 0.166; // lasts for 4 hours

          If ORequest.Response.GetSimpleValue(csRefreshToken, lvToken) Then
            OAccessToken.Refresh := lvToken; // new refresh token

          OAccessToken.Expires := Date + 547; // can refresh for up to 18 months

          // this token now needs to be saved, but that is for the owner application
          // set the new access token in the authenticator
          (Authenticator As TOAuth2Authenticator).AccessToken := OAccessToken.Access;

          // check whether we can save the changes
          If (Assigned(@OnTokenChange)) Then
          Begin
            OnTokenChange(Self, FUID, FAuthScope, OAccessToken.Access, OAccessToken.Refresh, OAccessToken.Expires,
              OAccessToken.TimeOut);
            FTokenState := tsOK;
          End
          Else
            FTokenState := tsUpdated;
        End;
      End // if token
      Else
      Begin
        Raise Exception.Create(csMsgNoTokenRtn);
      End;
    End // if success
    Else
    Begin
      Raise Exception.Create(csMsgBadResponse);
    End;
  End; // if pos > 0
End;

(* ****************************************************************************
  *  Close the login form - fired as an event.                                 *
  **************************************************************************** *)
Procedure THMRCRestClient.NAT_WebFormClose(Sender: TObject; Var Action: TCloseAction);
Var
  lvForm: TOAuthWebForm;
Begin
  lvForm := Sender AS TOAuthWebForm;
  If (lvForm <> Nil) Then
  Begin
    lvForm.OnAfterRedirect := Nil;
    lvForm.Release;
  End;
End;

(* ****************************************************************************
  *  Try to login and get a new user access token.                             *
  **************************************************************************** *)
Function THMRCRestClient.NewAccessToken: boolean;
Var
  lvForm: TOAuthWebForm;
  lURL: String;
Begin
  Result := False;
  If (NAT_CheckReady) Then
  Begin
    lURL := NAT_BildAuthUrl;
    lvForm := TOAuthWebForm.Create(Owner);
    // lvForm.Width := 550;
    lvForm.OnAfterRedirect := NAT_TryForToken; // possibly use OnBeforeRedirect on Android/Mobile ??
    lvForm.Caption := csHmrcLogin;
    lvForm.OnClose := NAT_WebFormClose;
    lvForm.ShowWithURL(NAT_BildAuthUrl);

    // do we know the outcome here ?
    Result := true; // at least there were no errors up to this point
  End
  Else
    Raise Exception.Create(FLastError);
End;

(* ****************************************************************************
  *                    REFRESH ACCESS TOKEN (RAT) SECTION                      *
  ******************************************************************************
  *  Get a new access token using the current refresh token.                   *
  **************************************************************************** *)
Function THMRCRestClient.RAT_RefreshToken: integer;
Var
  lvToken: String;
Begin
  Result := RESULT_NONE;
  Try
    REQ_ClearLast;
    REQ_Reset;
    RAT_SetOAuth2;

    // now rebuild the request to get the new access token
    ORequest.Method := TRESTRequestMethod.rmPOST;
    ORequest.Resource := csAuthToken;
    ORequest.Params.AddItem(csGrantType, csRefreshToken, TRESTRequestParameterKind.pkGETorPOST);
    ORequest.Params.AddItem(csRefreshToken, OAccessToken.Refresh, TRESTRequestParameterKind.pkGETorPOST);
    ORequest.Params.AddItem(csClientId, FClientId, TRESTRequestParameterKind.pkGETorPOST);
    ORequest.Params.AddItem(csClientSecret, FClientSecret, TRESTRequestParameterKind.pkGETorPOST);
    ORequest.Params.AddItem(csRedirectUri, FCallbackUrl, TRESTRequestParameterKind.pkGETorPOST);

    ORequest.Execute;

    FLastCode := ORequest.Response.StatusCode;
    FLastMsg := ORequest.Response.StatusText;

    // see what happened
    If (ORequest.Response.Status.Success) Then
    Begin
      If ORequest.Response.GetSimpleValue(csAccessToken, lvToken) Then
      Begin
        If (OAccessToken.Access <> lvToken) Then
        Begin
          // access token for scope
          OAccessToken.Access := lvToken;

          If ORequest.Response.GetSimpleValue(csExpiresIn, lvToken) Then
            // during testing the expiry time was always 14400 - which is 4 hours in seconds. 86400 seconds in a day.
            OAccessToken.TimeOut := Now + (StrToIntDef(lvToken, 14400) / 86400)
          Else
            // access token expiry is in 4 hours
            OAccessToken.TimeOut := Now + 0.166;

          // get the new refresh token
          If ORequest.Response.GetSimpleValue(csRefreshToken, lvToken) Then
          Begin
            OAccessToken.Refresh := lvToken;
          End;

          // set the new access token in the authenticator
          (Authenticator As TOAuth2Authenticator).AccessToken := OAccessToken.Access;

          // check whether we can save the changes
          If (Assigned(@OnTokenChange)) Then
          Begin
            OnTokenChange(Self, FUID, FAuthScope, OAccessToken.Access, OAccessToken.Refresh, OAccessToken.Expires,
              OAccessToken.TimeOut);
            FTokenState := tsOK;
          End
          Else
            FTokenState := tsUpdated;

          Result := RESULT_OK;
        End;
      End
      Else
      Begin
        FLastCode := ERR_NO_ACCESS_TOKEN;
        FLastError := csMsgNoTokenFnd + ORequest.Response.Content;
      End;
    End // if success
    Else
    Begin
      FLastCode := ERR_NO_ACCESS_TOKEN;
      FLastError := csMsgBadResponse + ' : ' + ORequest.Response.Content;
    End;
  Except
    On e: Exception Do
    Begin
      FLastCode := ERR_NO_ACCESS_TOKEN;
      FLastError := csMsgRefreshErr + e.Message;
      Result := RESULT_FAIL;
    End;
  End;
End;

(* ****************************************************************************
  *  Set OAuth2 params for HMRC access token refresh.                          *
  *  Assumes that there is a current access token to refresh.                  *
  **************************************************************************** *)
Procedure THMRCRestClient.RAT_SetOAuth2;
Begin
  (Authenticator As TOAuth2Authenticator).AccessToken := '';
  (Authenticator As TOAuth2Authenticator).RefreshToken := OAccessToken.Refresh;
  (Authenticator As TOAuth2Authenticator).TokenType := TOAuth2TokenType.ttBEARER;
  (Authenticator As TOAuth2Authenticator).ResponseType := TOAuth2ResponseType.rtTOKEN;
  (Authenticator As TOAuth2Authenticator).ClientId := FClientId;
  (Authenticator As TOAuth2Authenticator).ClientSecret := FClientSecret;
  (Authenticator As TOAuth2Authenticator).Scope := FAuthScope;
  (Authenticator As TOAuth2Authenticator).AuthorizationEndpoint := BaseUrl + csAuthToken;
  (Authenticator As TOAuth2Authenticator).RedirectionEndpoint := FCallbackUrl;
End;

Procedure THMRCRestClient.RemoveaHeader(Const aName: String);
Var
  I: integer;
Begin
  For I := 0 To LHeaderList.Count - 1 Do
  Begin
    If LHeaderList[I].StartsWith(aName) Then
    Begin
      LHeaderList.Delete(I);
      Exit;
    End;
  End;
End;

(* ****************************************************************************
  *                          REQUEST SETTING SECTION                           *
  ******************************************************************************
  *  Create the accept header for the request with the current api version.    *
  **************************************************************************** *)
Function THMRCRestClient.REQ_BildAccept: String;
Begin
  Result := csApVnd + FApiVersion + csWithJson;
End;

(* ****************************************************************************
  *  Check whether there is a token, it is current and can be refreshed.       *
  **************************************************************************** *)
Function THMRCRestClient.REQ_CheckToken: boolean;
Begin
  Result := true;
  FTokenState := tsNone;
  // no authorisation required, so it must be ok
  // if (FAuthMode = amNone) then
  // Exit
  // Application authorisation requires a server token
  If (FAuthMode = amApplication) Then
  Begin
    If (FServerToken = '') Then
    Begin
      // this is a failure and the process cannot connect
      FLastError := csMsgNoSvrToken;
      FLastCode := ERR_NO_SERVER_TOKEN;
      Result := False;
    End
    Else
    Begin
      // assumes the token it has is correct - there is no way to validate it
      FTokenState := tsOK;
    End;
  End
  Else If (FAuthMode = amUser) Then
  Begin
    // is there an access token object ? if not, then it will need to get a new token
    If (Assigned(OAccessToken)) Then
    Begin
      // does it have an access token ?
      // no token should be an error condition, but just get a new access token - not failed yet
      If (OAccessToken.Access <> '') Then
      Begin
        // has it expired ?
        If (OAccessToken.Expires < Date) Then
        Begin
          FTokenState := tsExpired;
          FLastError := csMsgTokenExp;
          FLastCode := ERR_TOKEN_EXPIRED;
          Result := False;
        End // if expired
        Else
        Begin
          // has it timed out ?
          If (OAccessToken.TimeOut < Now) Then
          Begin
            // does it have a refresh token
            If (OAccessToken.Refresh <> '') Then
            Begin
              // try to refresh the access token
              If (RAT_RefreshToken <> RESULT_OK) Then
              Begin
                // ???    // set token state to expired
                FTokenState := tsExpired;
                FLastError := csMsgTokenExp;
                FLastCode := ERR_TOKEN_EXPIRED;
                Result := False;
              End;
            End
            Else
            Begin
              // cannot refresh, so set as expired
              FTokenState := tsExpired;
              FLastError := csMsgTokenExp;
              FLastCode := ERR_TOKEN_EXPIRED;
              Result := False;
            End;
          End // if timed out
          Else
          Begin
            FTokenState := tsOK;
          End; // else ok
        End; // else not expired
      End // if not empty
      Else
      Begin
        FLastError := csMsgNoTokenFnd;
        FLastCode := ERR_NO_ACCESS_TOKEN;
        Result := False;
      End; // else no token value
    End // if has access token
    Else
    Begin
      FLastError := csMsgNoTokenFnd;
      FLastCode := ERR_NO_ACCESS_TOKEN;
      Result := False;
    End; // else no token object
  End;
End;

(* ****************************************************************************
  *  Clear the last response values.                                           *
  **************************************************************************** *)
Procedure THMRCRestClient.REQ_ClearLast;
Begin
  FLastCode := 0;
  FLastError := '';
  FLastMsg := '';
  FLastValue := Nil;
End;

(* ****************************************************************************
  *  convert date to HMRC compatible date string.                              *
  **************************************************************************** *)
Function THMRCRestClient.REQ_DateFormat(Const Value: TDateTime): String;
Begin
  Result := FormatDateTime('YYYY-MM-DD', Value);
End;

Procedure THMRCRestClient.REQ_LoadHeaders;
Var
  ix1: integer;
  Vals: TArray<String>;
Begin
  If (Assigned(LHeaderList)) And (LHeaderList.Count > 0) Then
  Begin
    For ix1 := 0 To LHeaderList.Count - 1 Do
    Begin
      Vals := LHeaderList[ix1].Split(['|']);
      If (Length(Vals) = 3) And (Vals[2] = 'noencode') Then
      Begin
        ORequest.Params.AddHeader(Vals[0], Vals[1]).Options := [poDoNotEncode];
      End
      Else
      Begin
        // don't think we need to encode here as it could result in double encoding, which is not pretty
        ORequest.Params.AddHeader(Vals[0], Vals[1]);
        // ORequest.Params.AddHeader(Vals[0], UriEncode(Vals[1]));
      End;
    End;
  End;
End;

(* ****************************************************************************
  *  Reset the request parameters to defaults and rebuild headers.             *
  **************************************************************************** *)
Procedure THMRCRestClient.REQ_Reset;
Var
  tmp: String;
  Vals: TArray<String>;
Begin

  if FResetCount > 0 then
     ORequest.ResetToDefaults;
  Inc(FResetCount);

  // because we did reset defaults
  ORequest.Method := TRESTRequestMethod.rmGET;
  ORequest.Client := Self;
  ORequest.Accept := REQ_BildAccept; // was set in create event, but has just been cleared

  ORequest.Params.AddHeader(csAuthorization, csUBearer + ' ' + OAccessToken.Access);

  // add gov and vendor headers if supplied
  REQ_LoadHeaders;

  ORequest.Params.AddItem(csAccessToken, OAccessToken.Access, TRESTRequestParameterKind.pkGETorPOST);
  ORequest.Params.AddItem(csTokenType, csLBearer, TRESTRequestParameterKind.pkGETorPOST);
  ORequest.Params.AddItem(csScope, FAuthScope, TRESTRequestParameterKind.pkGETorPOST);

  (Authenticator As TOAuth2Authenticator).AccessToken := OAccessToken.Access;
  (Authenticator As TOAuth2Authenticator).TokenType := TOAuth2TokenType.ttBEARER;
  (Authenticator As TOAuth2Authenticator).ClientId := FClientId;
  (Authenticator As TOAuth2Authenticator).ClientSecret := FClientSecret;
  (Authenticator As TOAuth2Authenticator).Scope := FAuthScope;
End;

(* ****************************************************************************
  *                         PROPERTY METHODS SECTION                           *
  ******************************************************************************
  *  Get the last http status code.                                            *
  **************************************************************************** *)
Function THMRCRestClient.GetLastCode: integer;
Begin
  Result := FLastCode;
End;

(* ****************************************************************************
  *  Get the last error/failure message.                                       *
  **************************************************************************** *)
Function THMRCRestClient.GetLastError: String;
Begin
  Result := FLastError;
End;

(* ****************************************************************************
  *  Get the last http status message.                                         *
  **************************************************************************** *)
Function THMRCRestClient.GetLastMsg: String;
Begin
  Result := FLastMsg;
End;

(* ****************************************************************************
  *  Get the last response json value.                                         *
  **************************************************************************** *)
Function THMRCRestClient.GetLastValue: TJSONValue;
Begin
  Result := FLastValue;
End;

class procedure THMRCRestClient.InitialiseClassVars;
begin
  FResetCount := 0;
end;

(* ****************************************************************************
  *  Reset the accept parameters with the new api version.                     *
  **************************************************************************** *)
Procedure THMRCRestClient.SetApiVersion(Const Value: String);
Begin
  If (Not AnsiSametext(Value, FApiVersion)) Then
  Begin
    FApiVersion := Value;
    ORequest.Accept := REQ_BildAccept;
    Self.Accept := REQ_BildAccept;
  End;
End;

(* ****************************************************************************
  *  Set OAuth2 params for HMRC user login.                                    *
  **************************************************************************** *)
Procedure THMRCRestClient.SetAuthMode(Const Value: THmrcAuthMode);
Begin
  FAuthMode := Value;
End;

(* ****************************************************************************
  *  Set OAuth2 params for HMRC user login and try to find the access token.   *
  **************************************************************************** *)
Procedure THMRCRestClient.SetAuthScope(Const Value: String);
Begin
  FAuthScope := Value;
  OAccessToken := LAccessTokens.GetAccessToken(FUID, FAuthScope);
End;

(* ****************************************************************************
  *  Set OAuth2 params for HMRC user login.                                    *
  **************************************************************************** *)
Procedure THMRCRestClient.SetCallbackUrl(Const Value: String);
Begin
  FCallbackUrl := Value;
End;

(* ****************************************************************************
  *  Set the header list.                                                      *
  **************************************************************************** *)
Procedure THMRCRestClient.SetHeaderList(Const Value: TStringList; OwnsList: boolean);
Begin
  If (Assigned(Value)) Then
  Begin
    If (Assigned(LHeaderList)) And (FOwnsHeaders) Then
      LHeaderList.Free;

    LHeaderList := Value;
    FOwnsHeaders := OwnsList;
  End;
End;

(* ****************************************************************************
  *  Set the test status - changes the base url.                               *
  **************************************************************************** *)
Procedure THMRCRestClient.SetIzTest(Const Value: boolean);
Begin
  If (FIzTest <> Value) Then
  Begin
    FIzTest := Value;
    If (FIzTest) Then
      BaseUrl := HmrcTestUrl
    Else
      BaseUrl := HmrcProdUrl;
  End;
End;

(* ****************************************************************************
  *  Set User ID for HMRC user login and try to find the access token.         *
  **************************************************************************** *)
Procedure THMRCRestClient.SetUID(Const Value: String);
Begin
  FUID := Value;
  OAccessToken := LAccessTokens.GetAccessToken(FUID, FAuthScope);
End;

{ THmrcTestClient }

(* ****************************************************************************
  *                           HMRC REST CLIENT                                 *
  ******************************************************************************
  *                             INIT SECTION                                   *
  ******************************************************************************
  *  Init.                                                                     *
  **************************************************************************** *)
Constructor THmrcTestClient.Create(AOwner: TComponent);
Begin
  Inherited;

  BaseUrl := HmrcTestUrl;
  BaseResource := csHello;
  ORequest.Resource := csHello;

  Setlength(LScopeList, 1);
  LScopeList[0] := csHello;
End;

(* ****************************************************************************
  *                             ADD USERS SECTION                              *
  ******************************************************************************
  ******************************************************************************
  *  Create a new agent and return the details.                                *
  **************************************************************************** *)
Function THmrcTestClient.AddAgent: integer;
Begin
  Result := RESULT_NONE;
  REQ_ClearLast;
  If (NUS_CheckReady) Then
  Begin
    BaseUrl := HmrcTestUrl;
    ORequest.Resource := 'create-test-user/agents';
    // this is described as an option, but does not appear to work. I have left it in anyway
    ORequest.Params.AddHeader(csAuthorization, csUBearer + ' ' + FServerToken);

    // It requires the server token to be set as the access token in the OAuth2 thingy
    (Authenticator As TOAuth2Authenticator).TokenType := TOAuth2TokenType.ttBEARER;
    (Authenticator As TOAuth2Authenticator).AccessToken := FServerToken;
    (Authenticator As TOAuth2Authenticator).ClientId := FClientId;
    (Authenticator As TOAuth2Authenticator).ClientSecret := FClientSecret;

    ORequest.Method := TRESTRequestMethod.rmPOST;

    // hard-coded json string - this is the only option allowed
    ORequest.Body.Add('{"serviceNames": ["agent-services"]}', ctAPPLICATION_JSON);

    ORequest.Execute;

    FLastCode := ORequest.Response.StatusCode;
    FLastMsg := ORequest.Response.StatusText;

    If (ORequest.Response.StatusCode < 400) Then
    Begin
      FLastValue := ORequest.Response.JSONValue;
      Result := RESULT_OK;
    End
    Else
    Begin
      FLastError := csError + IntToStr(ORequest.Response.StatusCode) + '  ' + ORequest.Response.Content;
      Result := RESULT_FAIL;
    End;
  End
  Else
  Begin
    Result := RESULT_ERROR;
  End;
End;

(* ****************************************************************************
  *  Create a new company and return the details.                              *
  **************************************************************************** *)
Function THmrcTestClient.AddCompany: integer;
Begin
  Result := RESULT_NONE;
  REQ_ClearLast;
  If (NUS_CheckReady) Then
  Begin
    BaseUrl := HmrcTestUrl;
    ORequest.Resource := 'create-test-user/organisations';
    // this is described as an option, but does not appear to work. I have left it in anyway
    ORequest.Params.AddHeader(csAuthorization, csUBearer + ' ' + FServerToken);

    // It requires the server token to be set as the access token in the OAuth2 thingy
    (Authenticator As TOAuth2Authenticator).TokenType := TOAuth2TokenType.ttBEARER;
    (Authenticator As TOAuth2Authenticator).AccessToken := FServerToken;
    (Authenticator As TOAuth2Authenticator).ClientId := FClientId;
    (Authenticator As TOAuth2Authenticator).ClientSecret := FClientSecret;

    ORequest.Method := TRESTRequestMethod.rmPOST;

    // hard-coded json string - there are some other options available - see HMRC website
    ORequest.Body.Add('{"serviceNames": ["paye-for-employers", "submit-vat-returns", ' +
      '"national-insurance", "self-assessment", "mtd-income-tax", "mtd-vat"]}', ctAPPLICATION_JSON);

    ORequest.Execute;

    FLastCode := ORequest.Response.StatusCode;
    FLastMsg := ORequest.Response.StatusText;

    If (ORequest.Response.StatusCode < 400) Then
    Begin
      FLastValue := ORequest.Response.JSONValue;
      Result := RESULT_OK;
    End
    Else
    Begin
      FLastError := csError + IntToStr(ORequest.Response.StatusCode) + '  ' + ORequest.Response.Content;
      Result := RESULT_FAIL;
    End;
  End
  Else
  Begin
    Result := RESULT_ERROR;
  End;
End;

(* ****************************************************************************
  *  Create a new individual and return the details.                           *
  **************************************************************************** *)
Function THmrcTestClient.AddPerson: integer;
Begin
  Result := RESULT_NONE;
  REQ_ClearLast;
  If (NUS_CheckReady) Then
  Begin
    BaseUrl := HmrcTestUrl;
    ORequest.Resource := 'create-test-user/individuals';
    ORequest.Params.AddHeader(csAuthorization, csUBearer + ' ' + FServerToken);

    // It requires the server token to be set as the access token in the OAuth2 thingy
    (Authenticator As TOAuth2Authenticator).TokenType := TOAuth2TokenType.ttBEARER;
    (Authenticator As TOAuth2Authenticator).AccessToken := FServerToken;
    (Authenticator As TOAuth2Authenticator).ClientId := FClientId;
    (Authenticator As TOAuth2Authenticator).ClientSecret := FClientSecret;

    ORequest.Method := TRESTRequestMethod.rmPOST;

    // hard-coded json string -  - these are the only options allowed
    ORequest.Body.Add
      ('{"serviceNames": ["national-insurance", "self-assessment", "mtd-income-tax", "customs-services"]}',
      ctAPPLICATION_JSON);

    ORequest.Execute;

    FLastCode := ORequest.Response.StatusCode;
    FLastMsg := ORequest.Response.StatusText;

    If (ORequest.Response.StatusCode < 400) Then
    Begin
      FLastValue := ORequest.Response.JSONValue;
      Result := RESULT_OK;
    End
    Else
    Begin
      FLastError := csError + IntToStr(ORequest.Response.StatusCode) + '  ' + ORequest.Response.Content;
      Result := RESULT_FAIL;
    End;
  End
  Else
  Begin
    Result := RESULT_ERROR;
  End;
End;

(* ****************************************************************************
  *  Check details for an application level api call.                          *
  **************************************************************************** *)
Function THmrcTestClient.NUS_CheckReady: boolean;
Begin
  Result := NAT_CheckReady;
  If (Result) Then
  Begin
    If (FServerToken = '') Then
    Begin
      FLastError := csMsgNoSvrToken;
      FLastCode := ERR_NO_SERVER_TOKEN;
      Result := False;
    End;
  End;
End;

(* ****************************************************************************
  *  Call the hello application resource / end point. Uses the server token.   *
  **************************************************************************** *)
Function THmrcTestClient.TestFraudHeaders: integer;
Begin
  Result := RESULT_NONE;
  REQ_ClearLast;
  If (NUS_CheckReady) Then
  Begin
    REQ_LoadHeaders;
    BaseUrl := HmrcTestUrl;
    ORequest.Resource := 'test/fraud-prevention-headers/validate';
    // this is described as an option, but does not appear to work. I have left it in anyway
    ORequest.Params.AddHeader(csAuthorization, csUBearer + ' ' + FServerToken);

    // It requires the server token to be set as the access token in the OAuth2 thingy
    (Authenticator As TOAuth2Authenticator).TokenType := TOAuth2TokenType.ttBEARER;
    (Authenticator As TOAuth2Authenticator).AccessToken := FServerToken;
    (Authenticator As TOAuth2Authenticator).ClientId := FClientId;
    (Authenticator As TOAuth2Authenticator).ClientSecret := FClientSecret;

    ORequest.Method := TRESTRequestMethod.rmGET;

    ORequest.Execute;

    FLastCode := ORequest.Response.StatusCode;
    FLastMsg := ORequest.Response.StatusText;

    If (ORequest.Response.StatusCode < 400) Then
    Begin
      FLastValue := ORequest.Response.JSONValue;
      Result := RESULT_OK;
    End
    Else
    Begin
      FLastError := csError + IntToStr(ORequest.Response.StatusCode) + '  ' + ORequest.Response.Content;
      Result := RESULT_FAIL;
    End;
  End
  Else
  Begin
    Result := RESULT_ERROR;
  End;

End;

Function THmrcTestClient.TestHelloApplication: String;
Begin
  Result := '';
  REQ_ClearLast;
  FAuthMode := amApplication;
  If (NUS_CheckReady) Then
  Begin
    ORequest.ResetToDefaults; // should it do this every time ?
    // because we did reset defaults
    ORequest.Method := TRESTRequestMethod.rmGET;
    ORequest.Client := Self;
    ORequest.Accept := REQ_BildAccept; // was set in create event, but has just been cleared

    ORequest.Resource := csHello;
    ORequest.ResourceSuffix := 'application';
    // It requires the server token to be set as the access token in the OAuth2 thingy
    If (Not Assigned(Authenticator)) Then
      Authenticator := TOAuth2Authenticator.Create(Self);
    (Authenticator As TOAuth2Authenticator).TokenType := TOAuth2TokenType.ttBEARER;
    (Authenticator As TOAuth2Authenticator).AccessToken := FServerToken;

    ORequest.Execute;
    FLastCode := ORequest.Response.StatusCode;
    FLastMsg := ORequest.Response.StatusText;
    If (ORequest.Response.StatusCode < 400) Then
    Begin
      FLastValue := ORequest.Response.JSONValue;
      Result := FLastValue.GetValue<String>(csMessage);
    End
    Else
    Begin
      FLastError := csError + IntToStr(ORequest.Response.StatusCode) + '  ' + ORequest.Response.Content;
      Result := FLastError;
    End;
  End
  Else
  Begin
    Result := FLastError;
  End;
End;

(* ****************************************************************************
  *  Call the hello user resource / end point. Requires OAuth2 access token.   *
  *  If there is no token, it will call the get new access token method and    *
  *  when it is finished, it needs to be run again to caal the api.            *
  **************************************************************************** *)
Function THmrcTestClient.TestHelloUser: String;
Begin
  Result := '';
  Try
    FAuthMode := amUser;
    FAuthScope := csHello;
    If (REQ_CheckToken) Then
    Begin
      REQ_ClearLast;
      REQ_Reset;

      // hello user specific
      ORequest.Resource := 'hello/user';

      ORequest.Execute;

      FLastCode := ORequest.Response.StatusCode;
      FLastMsg := ORequest.Response.StatusText;
      If (ORequest.Response.Status.Success) Then
      Begin
        FLastValue := ORequest.Response.JSONValue;
        Result := FLastValue.GetValue<String>(csMessage);
      End
      Else
      Begin
        FLastError := IntToStr(ORequest.Response.StatusCode) + '  ' + ORequest.Response.Content;
        Result := FLastError;
      End;
    End
    Else
    Begin
      // tell the user that there is no access token and to try again
      Result := FLastError;
      // create the new access token that will be used when they try again
      NewAccessToken;
    End;
  Except
    On e: Exception Do
    Begin
      FLastError := csMsgTestUsrErr + e.Message;
      Result := FLastError;
    End;
  End;
End;

(* ****************************************************************************
  *  Call the hello world resource / end point. No security or validation.     *
  **************************************************************************** *)
Function THmrcTestClient.TestHelloWorld: String;
Begin
  Result := '';
  REQ_ClearLast;
  FAuthMode := amNone;
  If (NAT_CheckReady) Then
  Begin
    ORequest.ResetToDefaults;
    // because we did reset defaults
    ORequest.Method := TRESTRequestMethod.rmGET;
    ORequest.Client := Self;
    ORequest.Accept := REQ_BildAccept; // was set in create event, but has just been cleared

    ORequest.Resource := csHello;
    ORequest.ResourceSuffix := 'world';
    ORequest.Execute;

    FLastCode := ORequest.Response.StatusCode;
    FLastMsg := ORequest.Response.StatusText;

    If (ORequest.Response.StatusCode < 400) Then
    Begin
      FLastValue := ORequest.Response.JSONValue;
      Result := FLastValue.GetValue<String>(csMessage);
    End
    Else
    Begin
      FLastError := csError + IntToStr(ORequest.Response.StatusCode) + '  ' + ORequest.Response.Content;
      Result := FLastError;
    End;
  End
  Else
    Result := FLastError;
End;

{ THmrcNIClient }

(* ****************************************************************************
  *                            HMRC NI CLIENT                                  *
  ******************************************************************************
  *                             INIT SECTION                                   *
  ******************************************************************************
  *  Init.                                                                     *
  **************************************************************************** *)
Constructor THmrcNIClient.Create(AOwner: TComponent);
Begin
  Inherited;

End;

{ THmrcPAYEClient }

(* ****************************************************************************
  *                           HMRC PAYE CLIENT                                 *
  ******************************************************************************
  *                             INIT SECTION                                   *
  ******************************************************************************
  *  Init.                                                                     *
  **************************************************************************** *)
Constructor THmrcPAYEClient.Create(AOwner: TComponent);
Begin
  Inherited;

End;

{ THmrcSAClient }

(* ****************************************************************************
  *                            HMRC SA CLIENT                                  *
  ******************************************************************************
  *                             INIT SECTION                                   *
  ******************************************************************************
  *  Init.                                                                     *
  **************************************************************************** *)
Constructor THmrcSAClient.Create(AOwner: TComponent);
Begin
  Inherited;

End;

{ THmrcVATClient }

(* ****************************************************************************
  *                            HMRC VAT CLIENT                                 *
  ******************************************************************************
  *                             INIT SECTION                                   *
  ******************************************************************************
  *  Init.                                                                     *
  **************************************************************************** *)
Constructor THmrcVATClient.Create(AOwner: TComponent);
Begin
  Inherited;

  FAuthMode := amUser; // always user authentication
  FAuthScope := csReadVat; // change this if submitting returns

  Setlength(LScopeList, 2);
  LScopeList[0] := csReadVat;
  LScopeList[1] := csRiteVat;

End;

(* ****************************************************************************
  *                          API METHODS SECTION                               *
  ******************************************************************************
  *  Call VAT Liabilities / Obligations / Payments for a date range. The only  *
  *  difference is the last element of the resource.                           *
  **************************************************************************** *)
Function THmrcVATClient.API_SearchLP(Const aType: String; Const FromDate, ToDate: TDateTime): integer;
Begin
  Result := RESULT_NONE;
  Try
    REQ_ClearLast;
    If (FUID <> '') Then
    Begin
      If (PRM_CheckDates(FromDate, ToDate)) Then
      Begin
        AuthScope := csReadVat;
        If (REQ_CheckToken) Then
        Begin
          REQ_ClearLast;
          REQ_Reset;

          // search specific
          ORequest.Resource := csOrgsVat + FUID + '/' + aType;
          ORequest.Params.AddItem(csFrom, FDateFrom, TRESTRequestParameterKind.pkGETorPOST);
          ORequest.Params.AddItem(csTo, FDateTo, TRESTRequestParameterKind.pkGETorPOST);

          ORequest.Execute;

          FLastCode := ORequest.Response.StatusCode;
          FLastMsg := ORequest.Response.StatusText;
          If (ORequest.Response.Status.Success) Then
          Begin
            FLastValue := ORequest.Response.JSONValue;
            Result := RESULT_OK;
          End
          Else
          Begin
            FLastError := ORequest.Response.Content;
            Result := RESULT_FAIL;
          End; // else failed
        End // if token
        Else
        Begin
          // error message set in CheckToken
          Result := RESULT_FAIL;
        End;
      End // if dates
      Else
      Begin
        // error message set in check dates
        Result := RESULT_FAIL;
      End;
    End // if uid
    Else
    Begin
      FLastCode := ERR_NO_USER_ID;
      FLastMsg := csMsgNoUserId;
      Result := RESULT_FAIL;
    End;
  Except
    On e: Exception Do
    Begin
      FLastError := e.Message;
      Result := RESULT_ERROR;
    End;
  End;
End;

(* ****************************************************************************
  *  Get VAT liabilities details for a given date range.                       *
  **************************************************************************** *)
Function THmrcVATClient.GetLiabilities(Const FromDate, ToDate: TDateTime): integer;
Begin
  Result := API_SearchLP(csLiabilities, FromDate, ToDate);
End;

(* ****************************************************************************
  *  Get VAT obkigations details for a given date range.                       *
  **************************************************************************** *)
Function THmrcVATClient.GetObligations(Const FromDate, ToDate: TDateTime; aStatus: String = ''): integer;
Begin
  Result := RESULT_NONE;
  Try
    REQ_ClearLast;
    If (FUID <> '') Then
    Begin
      If (PRM_CheckDates(FromDate, ToDate)) Then
      Begin
        AuthScope := csReadVat;
        If (REQ_CheckToken) Then
        Begin
          REQ_ClearLast;
          REQ_Reset;

          // search specific
          ORequest.Resource := csOrgsVat + FUID + '/' + csObligations;
          ORequest.Params.AddItem(csFrom, FDateFrom, TRESTRequestParameterKind.pkGETorPOST);
          ORequest.Params.AddItem(csTo, FDateTo, TRESTRequestParameterKind.pkGETorPOST);
          If (aStatus = 'F') Or (aStatus = 'O') Then
            ORequest.Params.AddItem(csStatus, aStatus, TRESTRequestParameterKind.pkGETorPOST);

          ORequest.Execute;

          FLastCode := ORequest.Response.StatusCode;
          FLastMsg := ORequest.Response.StatusText;
          If (ORequest.Response.Status.Success) Then
          Begin
            FLastValue := ORequest.Response.JSONValue;
            Result := RESULT_OK;
          End
          Else
          Begin
            FLastError := ORequest.Response.Content;
            Result := RESULT_FAIL;
          End; // else failed
        End // if token
        Else
        Begin
          // error message set in CheckToken
          Result := RESULT_FAIL;
        End;
      End // if dates
      Else
      Begin
        // error message set in check dates
        Result := RESULT_FAIL;
      End;
    End // if uid
    Else
    Begin
      FLastCode := ERR_NO_USER_ID;
      FLastMsg := csMsgNoUserId;
      Result := RESULT_FAIL;
    End;
  Except
    On e: Exception Do
    Begin
      FLastError := e.Message;
      Result := RESULT_ERROR;
    End;
  End;
End;

(* ****************************************************************************
  *  Get VAT payments details for a given date range.                          *
  **************************************************************************** *)
Function THmrcVATClient.GetPayments(Const FromDate, ToDate: TDateTime): integer;
Begin
  Result := API_SearchLP(csPayments, FromDate, ToDate);
End;

(* ****************************************************************************
  *  Get VAT Returns details for a given period.                               *
  **************************************************************************** *)
Function THmrcVATClient.GetReturn(Const aPeriod: String; Var ACorrelationId: String): integer;
Begin
  Result := RESULT_NONE;
  Try
    REQ_ClearLast;
    If (FUID <> '') Then
    Begin
      If (PRM_CheckPeriod(aPeriod)) Then
      Begin
        AuthScope := csReadVat;
        If (REQ_CheckToken) Then
        Begin
          REQ_ClearLast;
          REQ_Reset;

          // view returns specific
          ORequest.Resource := csOrgsVat + FUID + '/' + csReturns;
          ORequest.ResourceSuffix := URIEncode(aPeriod);

          ORequest.Execute;

          FLastCode := ORequest.Response.StatusCode;
          FLastMsg := ORequest.Response.StatusText;
          If (ORequest.Response.Status.Success) Then
          Begin
            FLastValue := ORequest.Response.JSONValue;
            ACorrelationId := ORequest.Response.Headers.Values['X-Correlationid'];
            Result := RESULT_OK;
          End
          Else
          Begin
            FLastError := ORequest.Response.Content;
            Result := RESULT_FAIL;
          End; // else failed
        End // if token
        Else
        Begin
          // error message set in CheckToken
          Result := RESULT_FAIL;
        End;
      End // if dates
      Else
      Begin
        // error message set in check period
        Result := RESULT_FAIL;
      End;
    End // if uid
    Else
    Begin
      FLastCode := ERR_NO_USER_ID;
      FLastMsg := csMsgNoUserId;
      Result := RESULT_FAIL;
    End;
  Except
    On e: Exception Do
    Begin
      FLastError := e.Message;
      Result := RESULT_ERROR;
    End;
  End;
End;

(* ****************************************************************************
  *  Submit VAT Returns details for a given period. Parse the confirmation     *
  *  details into a string list.                                               *
  **************************************************************************** *)
Function THmrcVATClient.SubmitReturn(Const aPeriod: String; Const Values: TStringList; Const IzFinal: boolean;
  Var Confirm: String): integer;
Var
  S, lLogName, lCorrelation, lCorrelationId, lReceipt, lReceiptId, lJSON: String;
  lVal: TArray<String>;
Begin
  Result := RESULT_NONE;
  Confirm := '';
  Try
    REQ_ClearLast;
    If (FUID <> '') Then
    Begin
      If (PRM_CheckPeriod(aPeriod)) Then
      Begin
        If (PRM_CheckValues(Values)) Then
        Begin
          AuthScope := csRiteVat;
          If (REQ_CheckToken) Then
          Begin
            REQ_ClearLast;
            REQ_Reset;
            // that set it to GET, so change it
            ORequest.Method := TRESTRequestMethod.rmPOST;

            // submit returns specific
            ORequest.Resource := csOrgsVat + FUID + '/' + csReturns;

            // the json is accepted if created like this using the JSONWriter element of the request
            ORequest.Body.JSONWriter.WriteStartObject;
            // add period
            ORequest.Body.JSONWriter.WritePropertyname('periodKey');
            ORequest.Body.JSONWriter.WriteValue(aPeriod);
            // add the list of numeric values
            ORequest.Body.JSONWriter.WritePropertyname(Values.Names[0]);
            ORequest.Body.JSONWriter.WriteValue(StrToFloat(Values.ValueFromIndex[0]));
            ORequest.Body.JSONWriter.WritePropertyname(Values.Names[1]);
            ORequest.Body.JSONWriter.WriteValue(StrToFloat(Values.ValueFromIndex[1]));
            ORequest.Body.JSONWriter.WritePropertyname(Values.Names[2]);
            ORequest.Body.JSONWriter.WriteValue(StrToFloat(Values.ValueFromIndex[2]));
            ORequest.Body.JSONWriter.WritePropertyname(Values.Names[3]);
            ORequest.Body.JSONWriter.WriteValue(StrToFloat(Values.ValueFromIndex[3]));
            ORequest.Body.JSONWriter.WritePropertyname(Values.Names[4]);
            ORequest.Body.JSONWriter.WriteValue(StrToFloat(Values.ValueFromIndex[4]));
            ORequest.Body.JSONWriter.WritePropertyname(Values.Names[5]);
            ORequest.Body.JSONWriter.WriteValue(StrToFloat(Values.ValueFromIndex[5]));
            ORequest.Body.JSONWriter.WritePropertyname(Values.Names[6]);
            ORequest.Body.JSONWriter.WriteValue(StrToFloat(Values.ValueFromIndex[6]));
            ORequest.Body.JSONWriter.WritePropertyname(Values.Names[7]);
            ORequest.Body.JSONWriter.WriteValue(StrToFloat(Values.ValueFromIndex[7]));
            ORequest.Body.JSONWriter.WritePropertyname(Values.Names[8]);
            ORequest.Body.JSONWriter.WriteValue(StrToFloat(Values.ValueFromIndex[8]));
            // add the finalised state
            ORequest.Body.JSONWriter.WritePropertyname('finalised');
            ORequest.Body.JSONWriter.WriteValue(IzFinal);
            // and close
            ORequest.Body.JSONWriter.WriteEndObject;

            ORequest.Execute;

            FLastCode := ORequest.Response.StatusCode;
            FLastMsg := ORequest.Response.StatusText;
            If (ORequest.Response.Status.Success) Then
            Begin
              lLogName := aPeriod + '_' + FormatDateTime('yyyymmddhhnnss', Now) + '.json';
              lLogName := TPath.Combine(StoreFolder, lLogName);

              lCorrelation := ORequest.Response.Headers[ORequest.Response.Headers.IndexOfName(csXCorrelationid)];
              Try
                lVal := lCorrelation.Split(['=']);
                lCorrelationId := lVal[1];
              Except
                lCorrelationId := 'unknown';
                lCorrelation := csXCorrelationid + '=' + lCorrelationId;
              End;

              lReceipt := ORequest.Response.Headers[ORequest.Response.Headers.IndexOfName(csReceiptId)];
              Try
                lVal := lReceipt.Split(['=']);
                lReceiptId := lVal[1];
              Except
                lReceiptId := 'unknown';
                lReceipt := csReceiptId + '=' + lReceiptId;
              End;

              lJSON := '{' + sLineBreak + '    "correlation-id":"$",'.Replace('$', lCorrelationId) + sLineBreak +
                '    "receipt-id":"$",'.Replace('$', lReceiptId);
              TFile.WriteAllText(lLogName, ORequest.Response.JSONText.Replace('{', lJSON));

              FLastValue := ORequest.Response.JSONValue;

              // we actually need to extract values from the response headers
              Confirm := lCorrelation + ';' + lReceipt;
              // ORequest.Response.Headers[ORequest.Response.Headers.IndexOfName(csXCorrelationid)];
              // Confirm := Confirm + ';' + ORequest.Response.Headers[ORequest.Response.Headers.IndexOfName(csReceiptId)];
              // and for convenience add them to the stringlist data
              Try
                If FLastValue.TryGetValue<String>(csProcessingdate, S) Then
                  Confirm := Confirm + ';' + csProcessingdate + '=' + S;
                If FLastValue.TryGetValue<String>(csPaymentIndicator, S) Then
                  Confirm := Confirm + ';' + csPaymentIndicator + '=' + S;
                If FLastValue.TryGetValue<String>(csFormBundleNumber, S) Then
                  Confirm := Confirm + ';' + csFormBundleNumber + '=' + S;
                If FLastValue.TryGetValue<String>(csChargeRefNumber, S) Then
                  Confirm := Confirm + ';' + csChargeRefNumber + '=' + S;
              Except
                // let's not fail just because of an error here
              End;
              Result := RESULT_OK;
            End
            Else
            Begin
              FLastError := ORequest.Response.Content;
              Result := RESULT_FAIL;
            End; // else failed
          End // if token
          Else
          Begin
            // error message set in CheckToken
            Result := RESULT_FAIL;
          End;
        End // if values
        Else
        Begin
          FLastCode := ERR_INVALID_DATA;
          FLastMsg := csMsgBadData;
          Result := RESULT_FAIL;
        End;
      End // if dates
      Else
      Begin
        // error message set in check period
        Result := RESULT_FAIL;
      End;
    End // if uid
    Else
    Begin
      FLastCode := ERR_NO_USER_ID;
      FLastMsg := csMsgNoUserId;
      Result := RESULT_FAIL;
    End;
  Except
    On e: Exception Do
    Begin
      FLastError := e.Message;
      Result := RESULT_ERROR;
    End;
  End;
End;

(* ****************************************************************************
  *                        VALIDATION METHODS SECTION                          *
  ******************************************************************************
  *  Check the vat search parameters are valid date ranges.                    *
  **************************************************************************** *)
Function THmrcVATClient.PRM_CheckDates(Const dtFrom, dtTo: TDateTime): boolean;
Begin
  Result := true;
  If (dtFrom > dtTo) Then
  Begin
    FLastCode := ERR_DATE_ERROR;
    FLastError := csMsgDateError;
    Result := False;
  End
  Else If ((dtTo - dtFrom) > 365) Then
  Begin
    FLastCode := ERR_DATE_RANGE;
    FLastError := csMsgDateRange;
    Result := False;
  End
  Else If (dtFrom < 1) Then
  Begin
    FLastCode := ERR_DATE_LOW;
    FLastError := csMsgDateLow;
    Result := False;
  End
  Else If (dtFrom > (Date + 365)) Then
  Begin
    FLastCode := ERR_DATE_HIGH;
    FLastError := csMsgDateHigh;
    Result := False;
  End
  Else
  Begin
    FDateFrom := REQ_DateFormat(dtFrom);
    FDateTo := REQ_DateFormat(dtTo);
  End;
End;

(* ****************************************************************************
  *  Check the vat period is sort of sensible.                                 *
  **************************************************************************** *)
Function THmrcVATClient.PRM_CheckPeriod(Const Value: String): boolean;
Begin
  Result := true;
  If (Length(Value) <> 4) Then
  Begin
    FLastCode := ERR_INVALID_PERIOD;
    FLastError := csMsgBadPeriod;
    Result := False;
  End;
End;

(* ****************************************************************************
  *  Check the values supplied for submission are valid. Are there 9 and are   *
  *  they all numeric. It does not check for sign and decimal places.          *
  **************************************************************************** *)
Function THmrcVATClient.PRM_CheckValues(Const Values: TStringList): boolean;
Var
  idx: integer;
Begin
  Result := true;
  If (Values = Nil) Then
  Begin
    FLastCode := ERR_NO_DATA;
    FLastError := csMsgNoData;
    Result := False;
  End
  Else If (Values.Count <> 9) Then
  Begin
    FLastCode := ERR_INVALID_DATA;
    FLastError := csMsgBadData;
    Result := False;
  End
  Else
  Begin
    For idx := 0 To Values.Count - 1 Do
    Begin
      If (Values.ValueFromIndex[idx] = '') Then
      Begin
        FLastCode := ERR_INVALID_DATA;
        FLastError := csMsgBadData;
        Result := False;
        Break;
      End
      Else If (StrToFloatDef(Values.ValueFromIndex[idx], 0) = 0) And
        (StrToFloatDef(Values.ValueFromIndex[idx], 10) = 10) Then
      Begin
        FLastCode := ERR_INVALID_DATA;
        FLastError := csMsgBadData;
        Result := False;
        Break;
      End;
    End; // for idx
  End;
End;

(* ****************************************************************************
  *  Perform basic checks on the user id as a VRN.                             *
  **************************************************************************** *)
Function THmrcVATClient.SetHmrcID(Const Value: String): integer;
Var
  lvUid: String;
Begin
  Result := RESULT_OK;

  lvUid := Trim(Value);
  // check it is not empty
  If (lvUid = '') Then
  Begin
    FLastCode := ERR_NO_USER_ID;
    FLastError := csMsgNoUserId;
    Result := RESULT_FAIL;
  End
  // check length is sensible
  Else If (Length(lvUid) <> 9) Then
  Begin
    FLastCode := ERR_INVALID_USER_ID;
    FLastError := csMsgBadUserId;
    Result := RESULT_FAIL;
  End
  // check it is a number
  Else If (StrToInt64Def(lvUid, 0) = 0) Then
  Begin
    FLastCode := ERR_INVALID_USER_ID;
    FLastError := csMsgBadUserId;
    Result := RESULT_FAIL;
  End
  // no problem so set it as the current user id
  Else
  Begin
    FUID := lvUid;
  End;
End;

initialization
THMRCRestClient.InitialiseClassVars;

End.
