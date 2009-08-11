unit usocketengine;

interface

uses
  uResourceStrings,
  forms,
  uencdec,
  Windows,
  SysUtils,
  WinSock,
  usharedstructs,
  classes,
  uVisualContainer,
  ComCtrls,
  SyncObjs,
  uMainReplacer;

const
  WSA_VER=$202;

type

 Ttunel = class (TObject)
  initserversocket,              //������������������ ��������� �����
  serversocket,              //��������� �����
  clientsocket : integer;    //����������
  curSockEngine : TObject;   //�������� ������ ��������� ���� ������ (��� �������� ����� �� ��������)
  ConnectOrErrorEvent : Cardinal;   //����� ����������� ��� ���������� ����������� ������
  hServerThread, hClientThread  : integer;  //������ �������
  idServerThread, idClientThread : LongWord;  //threadid �������
  sLastMessage : String;
  CriticalSection : TCriticalSection;
  tempfilename : string;
 private
 Public
  active : boolean;
  isRawAllowed: boolean;
  RawLog : TFileStream;
  Visual: TfVisual;
  NeedDeinit: boolean;
  AssignedTabSheet : TTabSheet;
  TunelWork:boolean;
  noFreeAfterDisconnect : Boolean; //�� ����� ������������ ������ ��� ����������
  noFreeOnServerDisconnect : boolean; //��� ���������� ������� ����� ������������������ ��������� �������
  noFreeOnClientDisconnect : boolean; //� ��������
  MustBeDestroyed : boolean;
  CharName : string;
  EncDec : TEncDec;
  Procedure AddToRawLog(dirrection : byte; var data; size:word);
  Procedure EncryptAndSend(Packet:Tpacket; ToServer:Boolean);
  procedure SendNewAction(action : byte);
  procedure NewAction(action : byte; Caller: TObject);
  procedure NewPacket(var Packet:tpacket; FromServer: boolean; Caller: TObject);
 Published
  constructor create(SockEngine : TObject);
  Procedure   RUN;
  destructor Destroy; override;
 end;

 TSocketEngine = class (TObject)
  sLastMessage:string;
   tunels : TList;  
 private
   WSA: TWSAData;
   hServerListenThread  : integer;
   idServerListenThread: Cardinal;
   ServerListenSock: Integer;
   procedure sendNewAction(Action : integer);
   procedure NewAction(action : byte; Caller: TObject);
   procedure sendMSG(MSG:string);
   
   function  WaitClient(var hSocket, NewSocket: TSocket): Boolean;
   function  WaitForData(Socket: TSocket; Timeout: Longint): Boolean;
   procedure DeInitSocket(VAR hSocket : integer; const ExitCode: Integer);
   function  InitSocket(var hSocket: TSocket; Port: Word; IP: String): Boolean;
   function  AuthSocks5(var sock:integer; var srvIP: Integer; var srvPort: Word): Boolean;
   function  GetSocketData(Socket: TSocket; var Data; const Size: Word): Boolean;
   function  ConnectToServer(var hSocket: TSocket; Port: Word; IP: Integer): Boolean;

 public
   //���������� ����� Init
   ServerPort : Word;
   //����� ������ � ������ ������
   isSocks5 : boolean;
   RedirrectIP : Integer;
   RedirrectPort : Word;
   //���������� ���� ���� ���� ����������
   isServerTerminating : boolean;
 published
   procedure destroyDeadTunels;
   constructor create; //�������� � �������������
   Procedure StartServer; //������, �������� ����� ������� � ��������� ���� ��������
   destructor Destroy; override; //�� ������� �������� ��� ��������� ���������� Ttunel
 end;

Procedure ClientBody(thisTunel:Ttunel);
Procedure ServerBody(thisTunel:Ttunel);
procedure showpacket(str:string; packet: TPacket);


implementation
uses uglobalfuncs, umain, Math;

{ TSocketEngine }
procedure TSocketEngine.DeInitSocket;
begin
  if isGlobalDestroying then exit;
  // ���� ���� ������ - ������� ��
  if (ExitCode <> 0) and (ExitCode <> 5) and (ExitCode <> 6) then
  begin
    if hsocket >= 0 then
      SendMSG(format(rsTsocketEngineSocketError, [hsocket, ExitCode, SysErrorMessage(ExitCode)]));
  end;
  // ��������� �����
  if hSocket <> INVALID_SOCKET then closesocket(hSocket);
  hSocket := -1;
end;



procedure showpacket(str:string; packet: TPacket);
begin
  OutputDebugString(pchar(str+ByteArrayToHex(packet.PacketAsByteArray,packet.Size)));;
end;

procedure ServerListen(CurrentEngine: TSocketEngine);
var
  NewSocket: TSocket;
  NewTunel : Ttunel;
begin
with CurrentEngine do
begin

    if not InitSocket(ServerListenSock, ServerPort, '0.0.0.0') then
    begin
      sendMSG(format(rsFailedLocalServer,[ServerPort]));
      exit;
    end;
    sendMSG(format(rsStartLocalServer,[ServerPort]));

    while WaitClient(ServerListenSock, NewSocket) do
    begin
      sendMSG(rsSocketEngineNewConnection);
      //����� ���������� �� ��������� �����. ������� ������.
      NewTunel := Ttunel.create(CurrentEngine);
      NewTunel.serversocket := NewSocket; //���� ���������� ������ = ��� �����������
      NewTunel.initserversocket := NewSocket; //���� ���������� ������ = ��� �����������
      NewTunel.CharName := '[Proxy]#'+IntToStr(NewSocket);
      NewTunel.RUN; //� ��������� ���
    end;
end;
end;

Procedure ServerBody(thisTunel:Ttunel);
var
  StackAccumulator : TCharArray;
  AccumulatorLen : integer;
  BytesInStack : Longint;
  curPacket : TPacket;
  LastResult : integer;
  EventTimeout : boolean;
  IP: Integer;
  IPb:array[0..3] of Byte absolute ip;
begin

with TSocketEngine(thisTunel.curSockEngine) do
begin
  //����������� �� ������, ������ �������� ����� ����������
  if isSocks5 then
    if not AuthSocks5(thisTunel.serversocket, RedirrectIP, RedirrectPort) then Exit;

  thisTunel.ConnectOrErrorEvent := CreateEvent(nil, true,false,PChar('ConnectOrErrorEvent'+
                                                      IntToStr(thisTunel.hServerThread)));

  //����� � ��������� �� ������
  thisTunel.hClientThread :=BeginThread(nil, 0, @ClientBody, thisTunel, 0, thisTunel.idClientThread);

  thisTunel.SendNewAction(Ttunel_Action_connect_server);

  EventTimeout := (WaitForSingleObject(thisTunel.ConnectOrErrorEvent, 30000) <> 0);
  if (EventTimeout) or (not thisTunel.TunelWork) then
    begin
      CloseHandle(thisTunel.ConnectOrErrorEvent);
      thisTunel.MustBeDestroyed := true; //������ ���� ������������ � ��� ��� ���� ������ �� �����.
      thisTunel.TunelWork := false;
      AddToLog(Format(rsTunelTimeout, [integer(pointer(thisTunel))]));

      DeinitSocket(thisTunel.serversocket,WSAGetLastError);
      TerminateThread(thisTunel.hServerThread,0);
    end;
    CloseHandle(thisTunel.ConnectOrErrorEvent);


  ip := RedirrectIP;
  AddToLog(Format(rsTunelConnected, [integer(pointer(thisTunel)), thisTunel.initserversocket, thisTunel.clientsocket, IntToStr(IPb[0])+'.'+IntToStr(IPb[1])+'.'+IntToStr(IPb[2])+'.'+IntToStr(IPb[3]), ntohs(RedirrectPort)]));
  //////////////////////////////////////////////////////////////
  AccumulatorLen := 0;
  LastResult := 1;
  
  While (LastResult > 0) and (thisTunel.serversocket <> -1) do
  begin //������ ���� �� ���������
    //������� ��� � ������ ?!
    ioctlsocket(thisTunel.serversocket, FIONREAD, Longint(BytesInStack));
    if BytesInStack = 0 then
      BytesInStack := 1;
    LastResult := recv(thisTunel.serversocket, StackAccumulator[AccumulatorLen], BytesInStack, 0);//������ 1 ���� ��� ���� ������ �����

    if LastResult > 0 then
    begin
    inc(AccumulatorLen, LastResult);
    thisTunel.AddToRawLog(PCK_GS_ToServer, StackAccumulator[AccumulatorLen-LastResult], LastResult);

    if not thisTunel.EncDec.Settings.isNoProcessToServer then
      begin
        if AccumulatorLen >= 2 then
          begin //� ����������� ������ �� 2+ ��������
            try
            thisTunel.CriticalSection.enter;
            //������ �����
            curPacket.PacketAsCharArray := StackAccumulator;
            //������ �� � ����������� ������ ��� ������ ?
              while (AccumulatorLen >= curPacket.Size) and (AccumulatorLen >= 2) and (curPacket.Size >= 2) do
                begin
                  //������� � ��������� ����� �����������
                  move(StackAccumulator[curPacket.Size], StackAccumulator[0], AccumulatorLen);
                  //�������� ������
                  fillchar(curPacket.PacketAsCharArray[curPacket.Size],AccumulatorLen-curPacket.Size,#0);
                  //��������� ����� � �����������
                  dec(AccumulatorLen,curPacket.Size);
                  if curPacket.Size > 2 then
                  begin
                    //����������
                    thisTunel.EncDec.DecodePacket(curPacket, PCK_GS_ToServer);

                    //���� ����� ����������� � ��������� ����� ��� ��� ���� ��
                    if curPacket.Size >= 2 then
                    begin
                      //��������
                      thisTunel.EncDec.EncodePacket(CurPacket, PCK_GS_ToServer);
                      //� ����������
                      send(thisTunel.clientsocket, curPacket, curPacket.Size, 0);
                    end;
                  end;

                  //�������� �������� �����. ��� �����
                  if AccumulatorLen >= 2 then
                      curPacket.PacketAsCharArray := StackAccumulator
                    else
                      FillChar(curPacket.PacketAsByteArray[0], $ffff, #0);
                end;
            finally
            thisTunel.CriticalSection.Leave;
            end;
          end; // if AccumulatorLen >= 2 then
      end //if not thisTunel.EncDec.Settings.isNoDecryptToServer then
    else //�� ���� ��������. ������ ����.
      begin
        send(thisTunel.clientsocket, StackAccumulator[0], AccumulatorLen, 0);
        AccumulatorLen := 0;
      end;
    end;
  end;//While LastResult <> SOCKET_ERROR do

  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  //���� �������� ����� ��������� ������
  //����� � ���
  AddToLog(Format(rsTunelServerDisconnect, [integer(pointer(thisTunel))]));

  //���������� �������
  thisTunel.sendNewAction(Ttunel_Action_disconnect_server);
    
  //��������� ��������� ������ � �������
  thisTunel.Visual.ThisOneDisconnected;

  //����� � ��� (�������� �����)
  DeinitSocket(thisTunel.serversocket,WSAGetLastError);

  //�� ��������� ����� c �������� ���� �������� ������ � noFreeOnServerDisconnect
  while thisTunel.noFreeOnServerDisconnect and (thisTunel.clientsocket <> -1) do sleep(1);

  //���������  ������
  if thisTunel.clientsocket <> -1 then
    DeinitSocket(thisTunel.clientsocket,WSAGetLastError);
  thisTunel.TunelWork := false;

  //������ ����� ������� ������ ��������� ���� ����.
  if not thisTunel.noFreeAfterDisconnect then
    thisTunel.MustBeDestroyed := true;
end;
end;

Procedure ClientBody(thisTunel:Ttunel);
var
  socks5ok : string;
  StackAccumulator : TCharArray;
  AccumulatorLen : integer;
  BytesInStack : Longint;
  curPacket : TPacket;
  LastResult : integer;
  IP: Integer;
  IPb:array[0..3] of Byte absolute ip;
begin
with TSocketEngine(thisTunel.curSockEngine) do
begin
if not InitSocket(thisTunel.clientsocket,0,'0.0.0.0') then
  begin
    EndThread(0);
  end;
  ip := RedirrectIP;
  AddToLog(Format(rsTunelConnecting, [integer(pointer(thisTunel)), thisTunel.serversocket, thisTunel.clientsocket, IntToStr(IPb[0])+'.'+IntToStr(IPb[1])+'.'+IntToStr(IPb[2])+'.'+IntToStr(IPb[3]), ntohs(RedirrectPort)]));
  if not ConnectToServer(thisTunel.clientsocket, RedirrectPort, RedirrectIP) then
  begin
    SetEvent(thisTunel.ConnectOrErrorEvent); //��������� ��������� � ����� � ����������
    EndThread(0);
  end;

  if isSocks5 then
  begin
    socks5ok:=#5#0#0#1#$7f#0#0#1#0#0;
    send(thisTunel.serversocket, socks5ok[1], Length(socks5ok), 0);
  end;

  thisTunel.sendNewAction(Ttunel_Action_connect_client);
  thisTunel.TunelWork := true;
  SetEvent(thisTunel.ConnectOrErrorEvent); //��������� ��������� � ����� � ����������
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  AccumulatorLen := 0;
  LastResult := 1;
  
  While (LastResult > 0) and (thisTunel.clientsocket <> -1) do
  begin //������ ���� �� ���������
    //������� ��� � ������ ?!
    ioctlsocket(thisTunel.clientsocket, FIONREAD, Longint(BytesInStack));
    if BytesInStack = 0 then
      BytesInStack := 1;
    LastResult := recv(thisTunel.clientsocket, StackAccumulator[AccumulatorLen], BytesInStack, 0);//������ 1 ���� ��� ���� ������ �����

    if LastResult > 0 then
    begin
    inc(AccumulatorLen, LastResult);
    thisTunel.AddToRawLog(PCK_GS_ToClient, StackAccumulator[AccumulatorLen-LastResult], LastResult);

    if not thisTunel.EncDec.Settings.isNoProcessToClient then
      begin
        if AccumulatorLen >= 2 then
          begin //� ����������� ������ �� 2+ ��������
            try
            thisTunel.CriticalSection.enter;
            //������ �����
            curPacket.PacketAsCharArray := StackAccumulator;
            if curPacket.Size=29754 then curPacket.Size:=267;
            //������ �� � ����������� ������ ��� ������ ?
              while (AccumulatorLen >= curPacket.Size) and (AccumulatorLen >= 2) and (curPacket.Size >= 2) do
                begin
                  //������� � ��������� ����� �����������
                  move(StackAccumulator[curPacket.Size], StackAccumulator[0], AccumulatorLen);
                  //�������� ������
                  fillchar(curPacket.PacketAsCharArray[curPacket.Size],AccumulatorLen-curPacket.Size,#0);
                  //��������� ����� � �����������
                  dec(AccumulatorLen,curPacket.Size);
                  if curPacket.Size > 2 then
                  begin
                    //����������
                    thisTunel.EncDec.DecodePacket(curPacket, PCK_GS_ToClient);
                    //���� ����� ����������� � ��������� ����� ��� ��� ���� ��
                    if curPacket.Size >= 2 then
                    begin
                      //��������
                      thisTunel.EncDec.EncodePacket(CurPacket, PCK_GS_ToClient);
                      //� ����������
                      send(thisTunel.serversocket, curPacket, curPacket.Size, 0);
                    end;
                  end;

                  //�������� �������� �����. ��� �����
                  if AccumulatorLen >= 2 then
                      curPacket.PacketAsCharArray := StackAccumulator
                    else
                      FillChar(curPacket.PacketAsByteArray[0], $ffff, #0);
                end;
              finally
              thisTunel.CriticalSection.Leave;
              end;
          end; // if AccumulatorLen >= 2 then
      end //if not thisTunel.EncDec.Settings.isNoDecryptToServer then
    else //�� ���� ��������. ������ ����.
      begin
        send(thisTunel.serversocket, StackAccumulator[0], AccumulatorLen, 0);
        AccumulatorLen := 0;
      end;
    end;
  end;//While LastResult <> SOCKET_ERROR do
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  //���� �������� ����� ��������� ������
    
  //����� � ���
  AddToLog(Format(rsTunelClientDisconnect, [integer(pointer(thisTunel))]));

  //���������� �������
  thisTunel.sendNewAction(Ttunel_Action_disconnect_client);

  //��������� ��������� ������ � �������
  thisTunel.Visual.ThisOneDisconnected;

  //����� � ��� (�������� �����)
  DeinitSocket(thisTunel.clientsocket,WSAGetLastError);

  //�� ��������� ����� c �������� ���� �������� ������ � noFreeOnClientDisconnect
  while (thisTunel.noFreeOnClientDisconnect) and (thisTunel.serversocket <> -1) do sleep(1);


  //��������� ��������� �����
  if thisTunel.clientsocket <> -1 then
    DeinitSocket(thisTunel.serversocket,WSAGetLastError);
  thisTunel.TunelWork := false;

  //������ ����� ������� ������ ��������� ���� ����.
  if not thisTunel.noFreeAfterDisconnect then
    thisTunel.MustBeDestroyed := true;
end;
end;




function TSocketEngine.initSocket(var hSocket: TSocket; Port: Word; IP: String): Boolean;
var
  Addr_in: sockaddr_in;
begin
  Result:=False;
  // ������� �����
  hSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if hSocket = INVALID_SOCKET then
  begin
    DeInitSocket(hSocket, WSAGetLastError);
    Exit;
  end;
  FillChar(Addr_in, SizeOf(sockaddr_in), 0);
  Addr_in.sin_family:= AF_INET;
  // ��������� �� ����� ����������� ����� �������
  Addr_in.sin_addr.s_addr := inet_addr(PChar(IP));
  Addr_in.sin_port := HToNS(Port);
  // ��������� ����� � ��������� �������
  if bind(hSocket, Addr_in, SizeOf(sockaddr_in)) <> 0 then  //������, ���� ������ ����
  begin
    DeInitSocket(hSocket, WSAGetLastError);
    Exit;
  end;
  Result:=True;
end;

constructor TSocketEngine.create;
begin
  isSocks5 := false;
  isServerTerminating := false;
  tunels := TList.Create;
end;

destructor TSocketEngine.destroy;
begin
  SuspendThread(hServerListenThread);
  while tunels.Count > 0  do
      Ttunel(tunels.Items[0]).Destroy;
  tunels.Destroy;
  TerminateThread(hServerListenThread, 0);
  WSACleanup;
  inherited;
end;


Procedure TSocketEngine.StartServer;
begin
if not (WSAStartup(WSA_VER, WSA) = NOERROR) then
  begin
    sendMSG(Format(rsTsocketEngineError,[SysErrorMessage(WSAGetLastError)]));
    exit;
  end;

hServerListenThread := BeginThread(nil, 0, @ServerListen, self, 0, idServerListenThread);
ResumeThread(hServerListenThread);
end;

procedure TSocketEngine.sendNewAction(Action: integer);
begin
  NewAction(action, Self);
end;

procedure TSocketEngine.sendMSG(MSG: string);
begin
if isGlobalDestroying then exit;
  sLastMessage := MSG;
  sendNewAction(TSocketEngine_Action_MSG);
end;

function TSocketEngine.WaitClient(var hSocket, NewSocket: TSocket): Boolean;
var
  Addr_in: sockaddr_in;
  AddrSize: Integer;
begin
  Result:=False;
  if listen(hSocket, 1)<>0 then
  begin
    DeInitSocket(hSocket, WSAGetLastError);
    Exit;
  end;
  FillChar(Addr_in,SizeOf(sockaddr_in), 0);
  Addr_in.sin_family:=AF_INET;
  Addr_in.sin_addr.s_addr:=inet_addr(PChar('0.0.0.0'));
  Addr_in.sin_port:=HToNS(0);
  AddrSize:=SizeOf(Addr_in);
  while not isServerTerminating do
  begin
    if WaitForData(hSocket, 5000) then
    begin
      NewSocket:=accept(hSocket, @Addr_in, @AddrSize);
      break;
    end;
  end;
  if NewSocket>0 then Result:=True;
  if not Result then
  begin
    DeInitSocket(hSocket,WSAGetLastError);
    DeInitSocket(NewSocket,WSAGetLastError);
  end;
end;
function TSocketEngine.WaitForData(Socket: TSocket;  Timeout: Integer): Boolean;
var
  FDSet: TFDSet;
  TimeVal: TTimeVal;
begin
  TimeVal.tv_sec := Timeout div 1000;
  TimeVal.tv_usec := (Timeout mod 1000) * 1000;
  FD_ZERO(FDSet);
  FD_SET(Socket, FDSet);
  Result := select(0, @FDSet, nil, nil, @TimeVal) > 0;
end;

function TSocketEngine.AuthSocks5(var sock:integer; var srvIP: Integer; var srvPort: Word): Boolean;
var
  buf: string;
  i: Integer;
  authOk: Boolean;
  p: PHostEnt;
begin
  Result:=False;
  // �������� ������ ������ � ���������� �������������� ������� �����������
  SetLength(buf,2);
  if(not GetSocketData(sock,buf[1],2))or(buf[1]<>#5)then
  begin
    DeInitSocket(sock,WSAGetLastError);
    Exit;
  end;

  // �������� �������������� �������� ������ �����������
  SetLength(buf,2+Byte(buf[2]));
  if(not GetSocketData(sock,buf[3],Byte(buf[2])))then
  begin
    DeInitSocket(sock,WSAGetLastError);
    Exit;
  end;
  authOk:=False;
  for i:=3 to Length(buf) do if buf[i]=#0 then authOk:=True;

  if not authOk then
  begin
    DeInitSocket(sock,WSAGetLastError);
    Exit;
  end;

  // ������� ��� ����������� �� ���������
  buf:=#5#0;
  send(sock,buf[1],2,0);

  // �������� ������ �� �����������
  SetLength(buf,4);
  if(not GetSocketData(sock,buf[1],4))
  or(buf[1]<>#5) // ��������� ������ ���������
  or(buf[2]<>#1) // ��������� ������� CMD = CONNECT
  then
  begin
    DeInitSocket(sock,WSAGetLastError);
    Exit;
  end;

  if(buf[4]=#1)then
  begin          // ���� ������� �� IP
    GetSocketData(sock,srvIP,4);
    GetSocketData(sock,srvPort,2);
    Result:=True;
  end else if(buf[4]=#3)then
  begin // ���� �� ��������� �����
    i:=0;
    GetSocketData(sock,i,1);
    SetLength(buf,i);
    GetSocketData(sock,buf[1],i);
    GetSocketData(sock,srvPort,2);
    p:=GetHostByName(PChar(buf));
    srvIP:=PInAddr(p.h_addr_list^)^.S_addr;
    Result:=True;
  end;
end;

function TSocketEngine.GetSocketData(Socket: TSocket; var Data;
  const Size: Word): Boolean;
var
  Position: Word;
  Len: Integer;
  DataB: array[0..$5000] of Byte absolute Data;
begin
  Result:=False;
  Position:=0;
  while Position<Size do
  begin
    Len:=recv(Socket,DataB[Position],1,0);
    if Len<=0 then Exit;
    Inc(Position, Len);
  end;
  Result:=True;
end;

function TSocketEngine.ConnectToServer(var hSocket: TSocket; Port: Word;
  IP: Integer): Boolean;
var
  Addr_in: sockaddr_in;
begin
  Result:=False;
  Addr_in.sin_family:=AF_INET;
  Addr_in.sin_addr.S_addr:=IP;
  Addr_in.sin_port:=Port;
  if connect(hSocket,Addr_in,SizeOf(Addr_in))=0 then Result:=True;
  if not Result then begin
    DeInitSocket(hSocket,WSAGetLastError);
  end;

end;

procedure TSocketEngine.destroyDeadTunels;
var
  i: integer;
begin
  if isGlobalDestroying then exit;
  if not Assigned(tunels) then exit;
  i := 0;
  while i < tunels.Count do
  begin
    if Ttunel(tunels.Items[i]).MustBeDestroyed then
    begin
      Ttunel(tunels.Items[i]).destroy;
      break;//����� ������� �� ������. ��� � 20 ��.
    end
    else
    inc(i);
  end;
end;

procedure TSocketEngine.NewAction(Action: byte; Caller: TObject);
begin
 if isGlobalDestroying then exit;
  if caller <> nil then
    SendMessage(fMainReplacer.Handle,WM_NewAction,integer(action),integer(caller));
end;

{ Ttunel }

constructor Ttunel.create;
begin
  active := false;
  Visual := nil;
  NeedDeinit := false;
  TSocketEngine(SockEngine).tunels.Add(self);
  isRawAllowed := GlobalRawAllowed;
  CriticalSection := TCriticalSection.Create;
  AddToLog(Format(rsTunelCreated, [integer(pointer(Self))]));
  TunelWork := false;
  noFreeAfterDisconnect := GlobalNoFreeAfterDisconnect;
  noFreeOnClientDisconnect := false;
  noFreeOnServerDisconnect := false;
  MustBeDestroyed := false;
  cursockengine := SockEngine;
  EncDec := TencDec.create;
  EncDec.ParentTtunel := Self;
  EncDec.ParentLSP := nil;
  EncDec.Settings := GlobalSettings;
  EncDec.onNewPacket := NewPacket;
  EncDec.onNewAction := NewAction;
  tempfilename := 'RAW.'+IntToStr(round(random(1000000)*10000))+'.temp';
  RawLog := TFileStream.Create(tempfilename,fmOpenWrite or fmCreate);

end;

destructor Ttunel.destroy;
var
  i: integer;
begin
  AddToLog(Format(rsTunelDestroy, [integer(pointer(Self))]));
  if assigned(curSockEngine) then TSocketEngine(curSockEngine).DeinitSocket(serversocket,WSAGetLastError);
  if assigned(curSockEngine) then TSocketEngine(curSockEngine).DeinitSocket(clientsocket,WSAGetLastError);

  if not Assigned(TSocketEngine(curSockEngine).tunels) then exit;
  i := 0;
  while i < TSocketEngine(curSockEngine).tunels.Count do
  begin
    if Ttunel(TSocketEngine(curSockEngine).tunels.Items[i]) = self then
    begin
      TSocketEngine(curSockEngine).tunels.Delete(i);
      break;
    end;
    inc(i);
  end;

  if Assigned(encdec) then EncDec.destroy;
  if hServerThread <> 0 then TerminateThread(hServerThread, 0);
  if hClientThread <> 0 then TerminateThread(hClientThread, 0);
  sendNewAction(Ttulel_action_tunel_destroyed);
  CriticalSection.Destroy;
  RawLog.Destroy;
  DeleteFile(tempfilename);
  inherited;
end;

procedure Ttunel.NewAction(action: byte; Caller: TObject);
begin
  if isGlobalDestroying then exit;
  SendMessage(fMainReplacer.Handle,WM_NewAction,integer(action),integer(caller));
end;

procedure Ttunel.NewPacket(var packet:tpacket; FromServer: boolean; Caller: TObject);
var
tmp : SendMessageParam;
begin
  if isGlobalDestroying then exit;
  if not assigned(caller) then exit;
  if ttunel(TencDec(Caller).ParentTtunel).MustBeDestroyed then exit;
  
  tmp := SendMessageParam.Create;
  tmp.packet := Packet;
  tmp.FromServer := FromServer;
  tmp.tunel := TencDec(Caller).ParentTtunel;
  tmp.Id := TencDec(Caller).Ident;
  SendMessage(fMainReplacer.Handle, WM_NewPacket, integer(@tmp), 0);
  Packet := tmp.packet;
  tmp.destroy;   
end;

procedure Ttunel.RUN;
begin
  //������������� �������������, �������� ��������� �� ������, �������� �������.
  EncDec.Ident := serversocket;
  EncDec.init;
  //�������� ����� �������������� ������ � �������
  hServerThread := BeginThread(nil, 0, @ServerBody, self, 0, idServerThread);
  ResumeThread(hServerThread);
  AddToLog(Format(rsTunelRUN, [integer(pointer(Self)), EncDec.Ident]));
  sendNewAction(Ttulel_action_tunel_created);
end;

procedure Ttunel.EncryptAndSend(Packet: Tpacket; ToServer: Boolean);
var
  sSendTo : TSocket;
begin
if isGlobalDestroying then exit;
if assigned(Visual) then
  begin
    Visual.AddPacketToAcum(Packet, not ToServer, EncDec);
    Visual.processpacketfromacum;
  end;


if ToServer then
  begin
    EncDec.EncodePacket(Packet, PCK_GS_ToServer);
    sSendTo := clientsocket;
  end
  else
  begin
    EncDec.EncodePacket(packet, PCK_GS_ToClient);
    sSendTo := serversocket;
  end;
  
if sSendTo <> -1 then
  Send(sSendTo, Packet, packet.Size, 0);
end;

procedure Ttunel.SendNewAction(action: byte);
begin
  if isGlobalDestroying then exit;
  NewAction(Action, self)
end;

procedure Ttunel.AddToRawLog(dirrection: byte; var data; size: word);
var
  dtime: Double;
begin
if isGlobalDestroying then exit;
  if not isRawAllowed then exit;
  RawLog.WriteBuffer(dirrection,1);
  RawLog.WriteBuffer(size,2);
  dtime := now;
  RawLog.WriteBuffer(dtime,8);
  RawLog.WriteBuffer(data,size);
end;

end.
