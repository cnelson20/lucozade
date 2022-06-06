unit Barrel;
{$ifdef fpc}
  {$mode delphi}
  {$h+}
  {$m+}
{$endif}

{@$apptype console}

interface
uses Classes, blcksock, sockets, Synautil, SysUtils, Generics.collections;

type
	TStringMap = TDictionary<String, String>;

	TRequest = class
	public
		uri : String;
		method : String;
		protocol : String;
	end;
	TResponse = class
	private
		ResponseHeaders : TStringMap;
	public
		Body : String; 
		Status : Word;

		constructor Create;
		destructor Destroy;
		procedure SetHeader(k, s : String);
	end;
	
	TRouteFunction = procedure(req : TRequest; res : TResponse);
	TRoutesMap = TDictionary<String, TRouteFunction>;
	
	TApp = class
	private
		Routes : TRoutesMap;
		DefaultHandler : TRouteFunction;

		procedure WriteHeaders(ASocket: TTCPBlockSocket; ResponseHeaders : TStringMap);
		procedure AttendConnection(ASocket: TTCPBlockSocket);
	public
		
		constructor Create;
		procedure SetDefaultHandler(Fxn : TRouteFunction);
		procedure AddRoute(s : String; Fxn : TRouteFunction);
		procedure SetDefaultHeader(k, h : String);
		procedure Run(Host : String; ListenPort : Word);
	end;
	
implementation

{
  Attends a connection. Reads the headers and gives an
  appropriate response
}
procedure TApp.AttendConnection(ASocket: TTCPBlockSocket);
var
	timeout: integer;
	s: string;
	method, uri, protocol: String;
	temp: String;
	ResultCode: integer;
	req : TRequest;
	res : TResponse;
	RouteFunction : TRouteFunction;
begin
	timeout := 120000;
	
	//read request line
	s := ASocket.RecvString(timeout);
	{ WriteLn(s); }
	method := fetch(s, ' ');
	uri := fetch(s, ' ');
	protocol := fetch(s, ' ');

	//read request headers
	repeat
		s := ASocket.RecvString(Timeout);
		//WriteLn(s);
	until s = '';

	// Now write the document to the output stream
	

	if Routes.ContainsKey(uri) then begin
		req := TRequest.Create;
		res := TResponse.Create; 

		req.uri := uri;
		req.method := method;
		req.protocol := protocol;

		RouteFunction := Routes.Items[uri];
		RouteFunction(req, res);

		WriteLn(method, ' ', uri, ' ', res.Status);
		ASocket.SendString('HTTP/1.0 ' + IntToStr(res.Status) + CRLF);
		WriteHeaders(ASocket, res.ResponseHeaders);

		ASocket.SendString(CRLF);
		
		ASocket.SendString(res.Body + CRLF);

		req.Destroy;
		res.Destroy;
	end else begin
		req := TRequest.Create;
		req.uri := uri;
		req.method := method;
		req.protocol := protocol;

		res := TResponse.Create;
		StatusHandlers.Items[404](req, res);
		ASocket.SendString('HTTP/1.0 ' + IntToStr(res.Status) + CRLF);
		WriteHeaders(ASocket, res.ResponseHeaders);
		ASocket.SendString(CRLF);
		ASocket.SendString(res.Body + CRLF);

		req.Destroy;
		res.Destroy;
	end;
end;

procedure TResponse.SetHeader(k, s : String);
begin
	ResponseHeaders.AddOrSetValue(k, s);
end;

constructor TResponse.Create;
begin
	ResponseHeaders := TStringMap.Create;
end;

destructor TResponse.Destroy;
begin
	ResponseHeaders.Destroy;
end;

procedure Handle404Default(req : TRequest; res : TResponse);
begin
	res.Body := 'The file at ' + req.uri + ' does not exist.';
end;

constructor TApp.Create;
begin
	DefaultHeaders := TStringMap.Create;
	DefaultHeaders.Add('Connection','close');
	DefaultHeaders.Add('Server','Pascal-Barrel using Synapse');
	
	Routes := TRoutesMap.Create;
	SetDefaultHandler(Handler404Default);
end;

procedure TApp.AddRoute(s : String; Fxn : TRouteFunction);
begin
	Routes.Add(s, Fxn);
end;

procedure TApp.SetDefaultHandler(Fxn : TRouteFunction);
begin
	DefaultHandler := Fxn;
end;

procedure TApp.WriteHeaders(ASocket: TTCPBlockSocket; ResponseHeaders : TStringMap);
var 
	i : LongInt;
	TempArray : TArray<TPair<String,String>>;
begin
	TempArray := DefaultHeaders.ToArray;
	for i := 0 to Length(TempArray) - 1 do begin
		if ResponseHeaders.ContainsKey(TempArray[i].Key) then begin
			ASocket.SendString(TempArray[i].Key + ': ' +  ResponseHeaders.Items[TempArray[i].Key] + CRLF);
		end else begin
			ASocket.SendString(TempArray[i].Key + ': ' +  TempArray[i].Value + CRLF);
		end;
	end;
end;

procedure TApp.SetDefaultHeader(k, h : String);
begin
	DefaultHeaders.Add(k, h);
end;

procedure TApp.Run(Host : String; ListenPort : Word);
var
  ListenerSocket, ConnectionSocket: TTCPBlockSocket;

begin
	ListenerSocket := TTCPBlockSocket.Create;
	ConnectionSocket := TTCPBlockSocket.Create;

	ListenerSocket.CreateSocket;
	ListenerSocket.setLinger(true,10);
	ListenerSocket.bind(Host,IntToStr(ListenPort));
	ListenerSocket.listen;

	WriteLn('Server running at', Host, ':', ListenPort, '/');

	repeat
		if ListenerSocket.canread(1000) then begin
			ConnectionSocket.Socket := ListenerSocket.accept;
			
			//WriteLn('Attending Connection. Error code (0=Success): ', ConnectionSocket.lasterror);
			AttendConnection(ConnectionSocket);
			ConnectionSocket.CloseSocket;
		end;
	until false;

	ListenerSocket.Free;
	ConnectionSocket.Free;
end;

end.

{if uri = '/' then begin
			// Write the output document to the stream
			OutputDataString :=
				'<!DOCTYPE html><html><h1>Hello World!</h1></html>' + CRLF;

			// Write the headers back to the client
			ASocket.SendString('HTTP/1.0 200' + CRLF);
			ASocket.SendString('Content-type: Text/Html' + CRLF);
			ASocket.SendString('Content-length: ' + IntTostr(Length(OutputDataString)) + CRLF);
			ASocket.SendString('Connection: close' + CRLF);
			ASocket.SendString('Date: ' + Rfc822DateTime(now) + CRLF);
			ASocket.SendString('Server: Pascal-Barrel using Synapse' + CRLF);
			ASocket.SendString('' + CRLF);

			//  if ASocket.lasterror <> 0 then HandleError;

			// Write the document back to the browser
			ASocket.SendString(OutputDataString);
		end;}