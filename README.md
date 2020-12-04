# HMRC-MTD
Updating Ian Hamilton's HMRC VAT Submission components and other shizzle

One of the big additions to HMRC VAT Submissions is the Anti-Fraud Headers. I'm still at a loss to see how some of these help combat fraud, but hey they say 'jump!' and we say 'how high?'

This is a description of how I implemented these using the HMRC Rest components developed by Ian Hamilton.

Note that the Objects are from Ian's FMX Directory but may be ok in VCL (not tested

There are 3 parts:

I. Changes to the code in the components;
II. Sourcing the data required by the headers;
III. Validating your headers.
 
While I have used FMX, it is only a Windows implementation and the code provided should work in VCL apps.

## I. Code Changes ##

THMRCRestClient 

1. Change 
  <code>procedure AddaHeader</code>:
<pre><code> 
    Procedure THMRCRestClient.AddaHeader(Const aName, aValue: String; Const NoEncode: boolean = False); 
    Const
    	_dont_encode: Array [boolean] Of String = ('encode', 'noencode');
    Begin
    	LHeaderList.Add(aName + '|' + aValue + '|' + _dont_encode[NoEncode]);
    End;
</code></pre>

note: I have changed the delimiter to '|' from a ':' as we will need to use the ':' in some values. Also added the new param 'NoEncode' as we need to do the encoding ourselves as it is not as straightforward as encoding the value.

2. add a new <pre><code>Procedure REQ_LoadHeaders;</code></pre> - this makes things simpler as we will need to also do this for the Test submissions.
<pre><code>    
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
            ORequest.Params.AddHeader(Vals[0], Vals[1]);
          End;
        End;
      End;
    End;
</code></pre> 

The original code for adding headers was in Procedure THMRCRestClient.REQ_Reset; so remove the code under the comment  *// add gov and vendor headers if supplied* and put in a call to *REQ_LoadHeaders;*. Also note the original code called <code>UriEncode(Vals[1])</code> - this is not needed as the base REST component does this unless told not to and can lead to problems with the new headers.

3. Add New <pre><code>Function THmrcTestClient.TestFraudHeaders: boolean</code></pre>

<pre><code>Function THmrcTestClient.TestFraudHeaders: integer;
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

End;</code></pre>


## II. Sourcing the data required by the headers ##

This only covers headers needed for DESKTOP_APP_DIRECT, if you are using any other type, you are on your own :-). I have listed the headers in the order they are listed on the HMRC Dev Web Page [https://developer.service.hmrc.gov.uk/api-documentation/docs/fraud-prevention](https://developer.service.hmrc.gov.uk/api-documentation/docs/fraud-prevention).

stop auto encoding means that you use <code>AddaHeader(name, value, **True**);</code>. The auto encoding has to be stopped because where there are lists you do not want to encode the delimiters. The values below show on what you need to <code>URIEncode()</code> which is in the unit *REST.Utils*. 
Code provided in source files in this repo:

<code>InternetSupport.SomeFunction</code> is a reference to *Systematic.Internet.Support.pas* they are class functions of the class *TInternetSupport*.

<code>Utils.SomeFunction</codes is a reference to *VAT.Header.Utils.pas* they are class functions of *THMRCMTDUtils*.  

<code>MACAddress.SomeFunction</code> is a reference to *Systematic.FMX.MacAddress.pas*.

**Gov-Client-Connection-Method**  
- stop auto encoding: No
- value: 'DESKTOP_APP_DIRECT'

**Gov-Client-Device-ID**
- stop auto encoding: Yes
- value: Create your own, use a GUID and store in the registry. This should never change

**Gov-Client-User-IDs**  
- stop auto encoding: Yes
- value: <code>'os=' + URIEncode(Utils.GetUserName)</code>
- notes: os does not stand for operating system as it does elsewhere in the HMRC documentation it is actually literal.

**Gov-Client-Timezone** 
- stop auto encoding: Yes
- Value:<code>Utils.getTimeZone</code> 

**Gov-Client-Local-IPs** 
- stop auto encoding: Yes 
- value: <code>InternetSupport.GetLocalIPs(',', True, True);</code>
- notes: They don't mean local IPs they mean private IPs. Each IP has to be encoded, but not the delimiter. That function manages that.

**Gov-Client-MAC-Addresses** 
- stop auto encoding: Yes
- value: <code>MacAddress.GetAllMacAddresses(True)</code>
- notes: Each mac address has to be encoded, but not the delimiter. That function manages that.

**Gov-Client-Screens**
- stop auto encoding: Yes
- value: <code>Utils.ScreensInfo</code>

**Gov-Client-Window-Size** 
- stop auto encoding: Yes
- value: <code>width=500&height=400</code>
- notes: set this to the width and height that you will use to show the OAUTH browser pop up.

**Gov-Client-User-Agent** 
- stop auto encoding: Yes
- value: <code>Utils.getUserAgent</code>
- notes: you will need https://github.com/RRUZ/tsmbios/uSMBIOS.pas

These headers are only required for **WEB_APP_VIA_SERVER** only so not needed
-   Gov-Client-Browser-Plugins
-   Gov-Client-Browser-JS-User-Agent
-   Gov-Client-Browser-Do-Not-Track

**Gov-Client-Multi-Factor** 
- stop auto encoding: not if leaving blank
- value: leave blank if you aren't using 2FA

**Gov-Vendor-Version** 
- stop auto encoding: Yes
- value: <code>URIEncode(SystemName)=Appversion</code> e.g. 'SMX%20VAT%20Submitter=1.1.1.1'

**Gov-Vendor-License-IDs** 
- stop auto encoding: Yes
- value: <code>UriEncode(Software)=HashedLicenceKey,UriEncode(Software2)=HashedLicenceKey</code>
- notes: may only be one software licence as in our case.

These headers arfe only required for ***_SERVER** Connection Methods
- Gov-Client-Public-IPFPublicIP
- Gov-Client-Public-Port
- Gov-Vendor-Forwarded

## III. Test the Headers ##  

- Make sure you subscribe for the header testing API on the HMRC Sandbox
- Make sure you are in test mode
- Call the new TestHeaders function                                                               




