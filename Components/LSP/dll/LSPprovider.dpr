
library LSPprovider;

uses
  JwaWS2spi,
  JwaWinType,
  JwaWinSock2,
  Windows,
  Sysutils,
  SyncObjs,
  math,
  overlapped in 'overlapped.pas',
  LSPStructures in '..\structures\LSPStructures.pas';

type
  Tselects=record
  result:integer;
  s: TSocket;
  hWnd: HWND;
  wMsg: u_int;
  lEvent: Longint;
  lpErrno: Integer;
  end;

var
  sprocessname:string;
  NextProcTable:WSPPROC_TABLE;
  glCS:TCriticalSection;
  cOverlapped: TOverlapped;
  hookthis:boolean;
  ShareMain : TshareMain;
  ShareClient : TshareClient;
  ReciverHandle:thandle = 0;
  ReciverWndClass:TWndClassEx;
  ReciverMEssageProcessThreadId: DWORD;
  ReciverMEssageProcessThreadHandle: THandle;
  Mmsg: MSG;  //���������

procedure debug(msg:string);
begin
  OutputDebugString(pchar(msg));
end;

function isMainWork:boolean;
var
  MutexHandle : THandle;
begin
result := false;
try
  //�������� ��������?
  MutexHandle := OpenMutex(MUTEX_ALL_ACCESS, false, Mutexname);
  if MutexHandle <> 0 then
    begin
      debug('Main APP work');
      CloseHandle(MutexHandle);
      Result := true;
    end
  else
    begin
      Result := false;
    end;
except
debug('!!!ERROR!!! isMainWork');
end;
end;

function isSocketHooked(SockNum:cardinal):boolean;
var
  MutexHandle : THandle;
begin
result := false;
glCS.Enter;
try
  //����� �������?
  MutexHandle := CreateMutex(nil, false, pchar(Mutexname+inttostr(SockNum)));
  If (GetLastError = ERROR_ALREADY_EXISTS) then
    begin
      CloseHandle(MutexHandle);
      Result := true //��.
    end
    else
    begin //���!
      ReleaseMutex(MutexHandle);
      CloseHandle(MutexHandle);
      result := false;
    end;
except
debug('!!!ERROR!!! isSocketHooked');
end;
glCS.Leave;
end;

procedure connecttosharememory(SocketNum:cardinal);
begin
    if ShareClient.SocketNum  = SocketNum then exit;
    ShareClient.MapHandle := CreateFileMapping(INVALID_HANDLE_VALUE, nil,
        PAGE_READWRITE, 0, SizeOf(TShareMapClient), pchar(Apendix + inttostr(SocketNum)));
    ShareClient.MapData := MapViewOfFile(ShareClient.MapHandle, FILE_MAP_ALL_ACCESS,
        0, 0, SizeOf(TShareMapClient));

end;

function ByteToHexStr(Data: Pointer; Len: Integer;calledfrom:string): String;
var
  I, Octets, PartOctets: Integer;
  DumpData: String;
begin
  result := '';
try
  if Len = 0 then Exit;
//  if Data = nil then exit;
  I := 0;
  Octets := 0;
  PartOctets := 0;
  Result := '';
  while I < Len do
  begin
    case PartOctets of
      0: Result := Result + Format('%.4d: ', [Octets]);
      9:
      begin
        Inc(Octets, 10);
        PartOctets := -1;
        Result := Result + '    ' + DumpData + sLineBreak;
        DumpData := '';
      end;
    else
      begin
        Result := Result + Format('%s ', [IntToHex(TByteArray(Data^)[I], 2)]);
        if TByteArray(Data^)[I] in [$19..$FF] then
          DumpData := DumpData + Chr(TByteArray(Data^)[I])
        else
          DumpData := DumpData + '.';
        Inc(I);
      end;
    end;
    Inc(PartOctets);
  end;
  if PartOctets <> 0 then
  begin
    PartOctets := (8 - Length(DumpData)) * 3;
    Inc(PartOctets, 4);
    Result := Result + StringOfChar(' ', PartOctets) +
      DumpData
  end;
except
  debug('!!!error!!! ByteToHexStr len = '+inttostr(Len)+' calledfrom='+calledfrom);
end;
end;


function WindowProc (wnd: HWND; msg: integer; wparam: WPARAM; lparam: LPARAM):LRESULT;STDCALL;
var
  newbuf : array[0..$ffff] of byte;
  len : cardinal;
begin
glCS.Enter;
result := 0;
try
  case msg of
  WM_action:
    if isSocketHooked(wparam) and isMainWork then //������������ ������ ������ ����� ��������. � �������� ��������
    case lparam of
    Action_sendtoserver: //�������� �� ����� �������. ������ �� ����� -)
      try
        //debug('Action_sendtoserver event. buffsize ('+inttostr(ShareClient.MapData^.buffersize)+')');
        connecttosharememory(wparam);
        ShareClient.MapData^.ignorenextsend := true;
        glCS.Leave;
        move(ShareClient.MapData^.Buff[0],newbuf[0],ShareClient.MapData^.buffersize);
        len := ShareClient.MapData^.buffersize;
        send(wparam, newbuf, len, 0);
        glCS.Enter;
      except
      end;
(*    Action_sendtoclient: //�������� �� ����� �������. ��� �������..
      try
      //���������� ������� ����� � ����������
      { TODO : ���������� ���� ����!! }
      //������ �� �������
      //ShareClient.MapData^.Buff;
      //����� ���� ������
      //ShareClient.MapData^.buffersize

      //������� ������
      //ShareClient.MapData^.toclientbuffer.Buff
      //�� ������
      //ShareClient.MapData^.toclientbuffer.buffsize

      //��������� � ���������� ���� ������
      Move(ShareClient.MapData^.Buff, ShareClient.MapData^.toclientbuffer.Buff[ShareClient.MapData^.toclientbuffer.buffsize], ShareClient.MapData^.buffersize);
      //� ����������� �� �����
      inc(ShareClient.MapData^.toclientbuffer.buffsize, ShareClient.MapData^.buffersize);
      except
      end;//*)

    Action_closesocket:
      try
        closesocket(wparam)
      except
      end;

  end;
  else
    Result := DefWindowProc(wnd,msg,wparam,lparam);
  end;
except
debug('!!!ERROR!!! WindowProc');
end;
glCS.Leave;
end;


procedure pReciverMessageProcess;
begin
try
  // ���� ��������� ���������}
  while GetMessage (Mmsg,0,0,0) do
  begin
    TranslateMessage (Mmsg);
    DispatchMessage (Mmsg);
  end;

except
debug('!!!ERROR!!! pReciverMessageProcess');
end;
end;

Function CreateReciverWnd:Thandle;
begin
try
 //��� ��� �� ������� ������.
  ReciverWndClass.cbSize := sizeof (ReciverWndClass);
  with ReciverWndClass do
  begin
    lpfnWndProc := @WindowProc;
    cbClsExtra := 0;
    cbWndExtra := 0;
    hInstance := HInstance;
    lpszMenuName := nil;
    lpszClassName := 'c'+Apendix;
  end;
  RegisterClassEx (ReciverWndClass);
  // �������� ���� �� ������ ���������� ������

  result := CreateWindow('c'+Apendix, 'c'+Apendix, 0,0,0,0,0,0,0,0,nil);
except
debug('!!!ERROR!!! CreateReciverWnd');
result := 0;
end;
end;

function WSPConnect(s: TSocket; name: PSockAddr; namelen: Integer; lpCallerData: LPWSABUF;
    lpCalleeData: LPWSABUF; lpSQOS: LPQOS; lpGQOS: LPQOS; var lpErrno: Integer): Integer; stdcall;
begin
glCS.Enter;
result := -1;
try
  if true then //isMainWork then
  begin
    try
      connecttosharememory(s);
      if (ShareClient.MapData^.ReciverHandle <> 0) and (ShareClient.SocketNum  = s) then exit;
      ShareClient.SocketNum  := s;
      ShareClient.MapData^.ignorenextsend := false;
    except
      debug('!!!ERROR!!! WSPConnect>x1 s='+inttostr(s));
    end;
    //��������� ���������
    if ReciverHandle = 0 then
        try
        ReciverHandle := CreateReciverWnd;
        //������� �����, ������� ����� ������������ ��������� �� ���������
        ReciverMessageProcessThreadHandle := CreateThread(nil, 0, @pReciverMessageProcess, nil, 0, ReciverMEssageProcessThreadId);
        ResumeThread(ReciverMEssageProcessThreadHandle);
        except
        debug('!!!ERROR!!! WSPConnect>x2 ReciverHandle='+inttostr(ReciverHandle)+', ReciverMessageProcessThreadHandle='+inttostr(ReciverMessageProcessThreadHandle));
        end;
    try
    ShareClient.MapData^.ip := inet_ntoa(name.sin_addr);
    ShareClient.MapData^.port := ntohs(Name.sin_port);
    ShareClient.MapData^.ReciverHandle := ReciverHandle;
    ShareClient.MapData^.application := sprocessname;
    ShareClient.MapData^.pid := GetCurrentProcessId;


    //���������� � ��������
    except
      debug('!!!ERROR!!! WSPConnect>x3');
    end;
    try
    SendMessage(ShareMain.MapData^.ReciverHandle,WM_action,s,Action_client_connect);
    except
      debug('!!!ERROR!!! WSPConnect>x4');
    end;
    //�� ��� ����������. ��������� ����.
    if not isSocketHooked(s) then
      begin
        UnmapViewOfFile(ShareClient.MapData); //���������� ����.
        CloseHandle(ShareClient.MapHandle);
      end;
  end;
  //���������� �������
  result:=NextProcTable.lpWSPConnect(s,name,namelen,lpCallerData,lpCalleeData,
          lpSQOS,lpGQOS,lpErrno);
  //debug('WSPConnect application('+sprocessname+') +result('+inttostr(result)+') socket ('+inttostr(s)+') ip/port ('+(ShareClient.MapData^.ip)+':'+inttostr(ShareClient.MapData^.port)+') lpErrno ('+inttostr(lpErrno)+')');

except
debug('!!!ERROR!!! WSPConnect '+inttostr(GetLastError));
end;
  glCS.Leave;
end;

function WSPCloseSocket(s: TSocket; var lpErrno: Integer): Integer; stdcall;
begin
  //��� ��������� �� ���� ������ ? ������������� � �������.
  if not isSocketHooked(s) then
  begin
    result:=NextProcTable.lpWSPCloseSocket(s,lperrno); //�����������
    exit;
  end;

  glCS.Enter;
  result := 0;
  try
  //�����������.
    connecttosharememory(s);
    SendMessage(ShareMain.MapData^.ReciverHandle,WM_action,s,Action_client_disconnect); //����������
    result:=NextProcTable.lpWSPCloseSocket(s,lperrno); //�����������
    //debug('WSPCloseSocket application('+sprocessname+') +result('+inttostr(result)+') socket ('+inttostr(s)+') lpErrno ('+inttostr(lpErrno)+')');
    UnmapViewOfFile(ShareClient.MapData); //���������� ����.
    CloseHandle(ShareClient.MapHandle);
  except
  debug('WSPCloseSocket code = '+inttostr(GetLastError));
  end;
  glCS.Leave;
end;

function WSPSend(s: TSocket; lpBuffers: LPWSABUF; dwBufferCount: DWORD;
    var lpNumberOfBytesSent: DWORD; dwFlags: DWORD; lpOverlapped: LPWSAOVERLAPPED;
    lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE;
    lpThreadId: LPWSATHREADID; var lpErrno: Integer): Integer; stdcall;
begin
  //���� ��� ���������� �� ����������� - ������ ������������ � �������.
  if not isSocketHooked(s) then
  begin
      result:=NextProcTable.lpWSPSend(s,lpBuffers,dwBufferCount,lpNumberOfBytesSent,
         dwFlags,lpOverlapped,lpCompletionRoutine,lpThreadId,lpErrno);
      exit;
  end;

result := -1;
try

glCS.Enter;
  //���������� � �����������
  connecttosharememory(s);
  //���� ��� �������� �������� ���� �����������
  if ShareClient.MapData^.ignorenextsend then
    begin
      //�� ������ ���������� ���� ���� ����������� ��� ��� �������� �� ����� ����������
      ShareClient.MapData^.ignorenextsend := false;
      //debug('WSPSend (������������) s ('+inttostr(s)+'). lpBuffers.len = '+IntToStr(lpBuffers.len)+' lpNumberOfBytesSent ('+inttostr(lpNumberOfBytesSent)+') ������:'+sLineBreak+ByteToHexStr(lpBuffers.buf,lpBuffers^.len,'WSPSend x1'));
      result:=NextProcTable.lpWSPSend(s,lpBuffers,dwBufferCount,lpNumberOfBytesSent,
         dwFlags,lpOverlapped,lpCompletionRoutine,lpThreadId,lpErrno);
    end
  else
    begin
      //��� �������� �������� ��������
      //debug('WSPSend (�� ���������) s ('+inttostr(s)+'). lpBuffers.len = '+IntToStr(lpBuffers.len)+' lpNumberOfBytesSent ('+inttostr(lpNumberOfBytesSent)+') ������:'+sLineBreak+ByteToHexStr(lpBuffers.buf,lpBuffers^.len,'WSPSend x1'));
      //�������� ����� � �����
      FillChar(ShareClient.MapData^.Buff[0], $ffff, #0);
      CopyMemory(@ShareClient.MapData^.Buff[0], @lpBuffers^.buf[0], lpBuffers^.len);
      ShareClient.MapData^.buffersize := lpBuffers^.len; //� ��� �����

      //� ����� ����� ������� ��� ������� ��� ����������. ������ ������ ����� �� ������ ��� �� �����
      //�� ������� ��� ��� ��������.
      result := 0;
      lpNumberOfBytesSent := lpBuffers.len;

      //�� � ���� ������, �������������� ���������:
      SendMessage(ShareMain.MapData^.ReciverHandle,WM_action,s,Action_client_send);

      //...������� ����
      ShareClient.MapData^.ignorenextsend := true;
      glCS.Leave;
      //����������.
      send(s, ShareClient.MapData^.Buff[0], ShareClient.MapData^.buffersize, 0);
      glCS.enter;
    end;
glCS.leave;
except
debug('!!!ERROR!!! WSPSend');
end;
end;



function WSPRecv(s: TSocket; lpBuffers: LPWSABUF; dwBufferCount: DWORD;
    var lpNumberOfBytesRecvd, lpFlags: DWORD; lpOverlapped: LPWSAOVERLAPPED;
    lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE; lpThreadId: LPWSATHREADID;
    var lpErrno: Integer): Integer; stdcall;
begin
  //debug('WSPRecv (����)');
  //��� ��������� �� ���� ������ ? ������������� � �������.
  if not isSocketHooked(s) then
  begin
    //debug('WSPRecv (�����)');

      result:=NextProcTable.lpWSPRecv(s,lpBuffers,dwBufferCount,lpNumberOfBytesRecvd,
                                lpFlags,lpOverlapped,lpCompletionRoutine,lpThreadId,
                                lpErrno);
      exit;
  end;
  
//���� �������� ���� ��� �� ������ �������  
result := -1;
try
  glCS.Enter;
  //�������������� � ShareClient.
  connecttosharememory(s);

  //��� ��������� ������ ��������. ������� ����� ������ ��� �� �������� ���������� ������� �������
  //������� �� ����������� �����������
  //� ����� ��� ������ ������ ����� �������� ��� �������.
  //����� ��������� � ��� � ����� ������ �����
  result:=NextProcTable.lpWSPRecv(s,lpBuffers,dwBufferCount,lpNumberOfBytesRecvd,
                                lpFlags,lpOverlapped,lpCompletionRoutine,lpThreadId,
                                lpErrno);

  //���� �������� ����������� ��� ������.
  //� �� ����� ��������
  if (result=0) and (lpNumberOfBytesRecvd>0) then
    begin
    //debug('WSPRecv (�� ���������)  S ('+inttostr(s)+'), dwBufferCount ('+IntToStr(dwBufferCount)+'), currentbuf.len ('+inttostr(lpBuffers.len)+'), lpNumberOfBytesRecvd = ('+inttostr(lpNumberOfBytesRecvd)+') ������ :'+sLineBreak+ByteToHexStr(lpBuffers.buf, lpNumberOfBytesRecvd,'WSPRecv x1'));
    //����� � ���� �� ��� ������ �������� ��������.
    FillChar(ShareClient.MapData^.Buff[0], $ffff, #0);
    CopyMemory(@ShareClient.MapData^.Buff[0], lpBuffers.buf, lpnumberofbytesrecvd);
    
    //� ��� �� ���-�� �������� ��������
    ShareClient.MapData^.buffersize := lpNumberOfBytesRecvd;
    glCS.Leave;
    //��������� ��������� � �������� ����������
    SendMessage(ShareMain.MapData^.ReciverHandle,WM_action,s,Action_client_recv); //���������� � ������
    glCS.Enter;

    if (ShareClient.MapData^.toclientbuffer.buffsize > 0) then
    try
      move(ShareClient.MapData^.Buff[0], ShareClient.MapData^.Buff[ShareClient.MapData^.toclientbuffer.buffsize], ShareClient.MapData^.buffersize);
      move(ShareClient.MapData^.toclientbuffer.Buff[0], ShareClient.MapData^.Buff[0], ShareClient.MapData^.toclientbuffer.buffsize);
      inc(ShareClient.MapData^.buffersize, ShareClient.MapData^.toclientbuffer.buffsize);
      ShareClient.MapData^.toclientbuffer.buffsize := 0;
    except
    end;

    //������������ �����
    lpnumberofbytesrecvd := ShareClient.MapData^.buffersize; //�������� ���������� ����� �������� ������, ����� ����� ��������� ������

    
    try
    CopyMemory(lpBuffers.buf, @ShareClient.MapData^.Buff, ShareClient.MapData^.buffersize); //�� � �����, �����������
    //debug('WSPRecv (����� ���������)  S ('+inttostr(s)+'), lpBuffers.len ('+inttostr(lpBuffers.len)+'), lpNumberOfBytesRecvd = ('+inttostr(lpNumberOfBytesRecvd)+') ������ :'+sLineBreak+ByteToHexStr(lpBuffers.buf, lpNumberOfBytesRecvd, 'WSPRecv x2'));
    except
      debug('!!!error!!!! WSPRecv �����, ������ ����� �� �� ���� ��� ������ ������ ������ �� ��������� � ��� �����������������');
    end;
  end
  else
    debug('WSPRecv FAIL! (��� �� ������) result = '+inttostr(result)+',  lpNumberOfBytesRecvd = '+ inttostr(lpNumberOfBytesRecvd) );
  glCS.Leave;
except
debug('!!!ERROR!!! WSPRecv �� ���');
end;
end;


const
  reg_key='SYSTEM\CurrentControlSet\Services\WinSock2\SockEyeS';
  MAX_PATH=1024;
  
function GetHookProvider(pProtocolInfo:LPWSAPROTOCOL_INFOW;var sPathName:string):boolean;
  procedure GetRightEntryIdItem(pProtocolInfo:LPWSAPROTOCOL_INFOW;var sItem:string);
  begin
    if pProtocolInfo.ProtocolChain.ChainLen<=1 then
      begin
        sItem:=inttostr(pProtocolInfo.dwCatalogEntryId);
      end
    else
      begin
        sItem:=inttostr(pProtocolInfo.ProtocolChain.ChainEntries[pProtocolInfo.ProtocolChain.ChainLen-1]);
      end;
  end;
var
  sItem:string;
  sTemp,
  sPathTmp:pchar;
  hSubKey: hkey;
  ulDateLenth: DWORD;
  Datatype,i:integer;
begin
  result:=true;
  GetRightEntryIdItem(pProtocolInfo,sItem);
  ulDateLenth:=MAX_PATH;
  getmem(sTemp,MAX_PATH);
  getmem(sPathTmp,MAX_PATH);
  try
    if RegOpenKeyEx(HKEY_LOCAL_MACHINE,pchar(reg_key),0,KEY_ALL_ACCESS,hSubKey)<>0 then
      begin
        result:=false;
        exit;
      end;
    if RegQueryValueEx(hSubKey,pchar(sItem),nil,@Datatype,pbyte(sTemp),@ulDateLenth)=0 then
      begin
        i:=ExpandEnvironmentStrings(sTemp,sPathTmp,ulDateLenth);
        if i<>0 then
          begin
            sPathName:=strpas(sPathTmp);
            RegCloseKey(hSubKey);
          end
        else
          begin
            result:=false;
            exit;
          end;
      end
    else
      begin
        result:=false;
        exit;
      end;
  finally
    freemem(sTemp);
    freemem(sPathTmp);
  end;
end;

function WSPioctrl(s: TSocket; dwIoControlCode: DWORD; lpvInBuffer: LPVOID; cbInBuffer: DWORD;
    lpvOutBuffer: LPVOID; cbOutBuffer: DWORD; var lpcbBytesReturned: DWORD;
    lpOverlapped: LPWSAOVERLAPPED; lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE;
    lpThreadId: LPWSATHREADID; var lpErrno: Integer): Integer; stdcall;
begin
  glCS.Enter;
  result := NextProcTable.lpWSPIoctl(s, dwIoControlCode, lpvInBuffer, cbInBuffer,
      lpvOutBuffer, cbOutBuffer, lpcbBytesReturned,
      lpOverlapped, lpCompletionRoutine,
      lpThreadId, lpErrno);

  if isSocketHooked(s) then
        debug('WSPioctrl result ('+inttostr(result)+') s ('+inttostr(s)+') dwIoControlCode ('+inttostr(dwIoControlCode)+
          ') cbInBuffer ('+inttostr(cbInBuffer)+') cbOutBuffer ('+inttostr(cbOutBuffer)
          +') lpcbBytesReturned ('+inttostr(lpcbBytesReturned)+') lpThreadId ('+inttostr(lpThreadId.ThreadHandle)+')'
          +') lpErrno ('+inttostr(lpErrno)+')');
  glCS.Leave;
end;


function WSPAsyncSelect(s: TSocket; hWnd: HWND; wMsg: u_int; lEvent: Longint; var lpErrno: Integer): Integer; stdcall;
begin
  glCS.Enter;
  result := NextProcTable.lpWSPAsyncSelect(s, hWnd, wMsg, lEvent, lpErrno);

  if isSocketHooked(s) then
  debug('WSPAsyncSelect s ('+inttostr(s)+') hWnd ('+inttostr(hWnd)+
      ') wMsg ('+inttostr(wMsg)+') lEvent ('+inttostr(lEvent)
      +') lpErrno ('+inttostr(lpErrno)+')');

  glCS.Leave;
end;


function WSPStartup(wVersionRequested: WORD; lpWSPData: LPWSPDATA;
  lpProtocolInfo: LPWSAPROTOCOL_INFOW; UpcallTable: WSPUPCALLTABLE;
  lpProcTable: LPWSPPROC_TABLE): Integer; stdcall;
var
  WSPStartupFunc:LPWSPSTARTUP;
  slibpath:string;
  hlibhandle:hmodule;
begin
 
  if not GetHookProvider(lpProtocolInfo,slibPath) then
    begin
      result:=WSAEPROVIDERFAILEDINIT;
      exit;
    end;
  hlibhandle:=loadlibrary(pchar(slibpath));
  if hlibhandle<>0 then
    begin
      WSPStartupFunc:= LPWSPSTARTUP(getprocaddress(hlibhandle,pchar('WSPStartup')));
      if assigned(WSPStartupFunc) then
        begin
          result:=WSPStartupFunc(wVersionRequested,lpWSPData,lpProtocolInfo,UpcallTable,lpProcTable);
          if (result=0) then
            begin
              glCS.Enter;
                NextProcTable:=lpProcTable^;
                ShareClient.MapHandle := 0;
                ShareClient.MapData := nil;
                ShareClient.SocketNum := 0;
                if hookthis then
                begin
                  //������ ���� ������� ���������.
                  lpProcTable.lpWSPConnect := WSPConnect;
                  lpProcTable.lpWSPCloseSocket := WSPCloseSocket;
                  lpProcTable.lpWSPSend := WSPSend;
                  lpProcTable.lpWSPRecv := WSPRecv;
//                  lpProcTable.lpWSPIoctl := WSPioctrl;
//                  lpProcTable.lpWSPAsyncSelect := WSPAsyncSelect;
//                  debug('������������ � ('+sprocessname+')');
                end;
                glCS.Leave;
              exit;
            end;
        end
      else
        begin
          result:=WSAEPROVIDERFAILEDINIT;
        end;
    end
  else
    begin
      result:=WSAEPROVIDERFAILEDINIT;
    end;
end;

procedure opensharemain;
begin
try
  //�������������� � �������� ��������� ����������.
  ShareMain.MapHandle := CreateFileMapping(INVALID_HANDLE_VALUE, nil,
        PAGE_READWRITE, 0, SizeOf(TShareMapMain), Apendix);
  ShareMain.MapData := MapViewOfFile(ShareMain.MapHandle, FILE_MAP_ALL_ACCESS,
        0, 0, SizeOf(TShareMapMain));
except
debug('!!!ERROR!!! opensharemain');
end;
end;


procedure DllMain(dwReason : DWORD);
var
  tmp:pchar;
begin
  case dwReason of
    DLL_PROCESS_ATTACH :
      begin
        cOverlapped := TOverlapped.create;
        glCS:=TCriticalSection.Create;
        try
        getmem(tmp,1024);
        hookthis := false;
        if getmodulefilenamea(0,tmp,1024)>0 then
          begin
            sprocessname:=strpas(tmp);
            debug(sprocessname+' - ���������� ���');
            if isMainWork then
              begin
              opensharemain;
              if pos(LowerCase(ExtractFileName(sprocessname)),LowerCase(ShareMain.MapData^.ProcessesForHook)) > 0 then
                hookthis := true; //����� �������������
              end;
          end
        else
          begin
            sprocessname:='';
            debug('������ ������������..');
          end;
        freemem(tmp);
        except
        debug('!!!ERROR!!! DLL_PROCESS_ATTACH');
        end;
      end;
      
    DLL_PROCESS_DETACH :
      begin
        if ReciverHandle <> 0 then
        begin
          TerminateThread(ReciverMEssageProcessThreadHandle,0);
          DestroyWindow(ReciverHandle);
        end;
        //debug(sprocessname+' �����������');
        cOverlapped.destroy;
        glCS.Free;
      end;

    DLL_THREAD_ATTACH :
      begin
      end;

    DLL_THREAD_DETACH :
      begin
      end;
  end;
end;

exports
  WSPStartup;

begin
  hookthis := false;
  DLLProc := @DLLMain;
  DLLMain(DLL_PROCESS_ATTACH);
end.
