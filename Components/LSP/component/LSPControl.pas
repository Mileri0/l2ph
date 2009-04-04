unit LSPControl;

interface

uses LSPInstalation, LSPStructures, windows, messages, sysutils, Classes, SyncObjs;

const
  LSP_Install_success = 1;
  LSP_Already_installed = 2;
  LSP_Uninstall_success = 3;
  LSP_Not_installed = 4;
  LSP_Install_error = 5;
  LSP_UnInstall_error = 6;
  LSP_Install_error_badspipath = 7;


resourcestring
  rsLSP_Install_success = 'LSP ������� ���������������.';
  rsLSP_Already_installed = 'LSP ������ ��������������� � �������';
  rsLSP_Uninstall_success = '����������� LSP ������ ������� �����';
  rsLSP_Not_installed = 'LSP ������ �� ���������������';
  rsLSP_Install_error = '������ ��� ����������� LSP ������. (��� ���� ������� � ������ �������?)';
  rsLSP_UnInstall_error = '������ ��� ������ ����������� LSP ������. (��� ���� ������� � ������ �������?)';
  rsLSP_Install_error_badspipath = '������� ������ ���� � LSP ������, ��������� ���������� ����,'#13#10'             ���� ������� ���������� LSP ������ � SYSTEM32';

type
  tOnSendOrRecv = procedure (SocketNum : cardinal; var buffer : Tbuffer; var len : cardinal) of object;
  tOnConnect = procedure (SocketNum : cardinal; ip:string; port:cardinal; exename:string; pid:cardinal; hook:boolean) of object;
  tOnDisconnect = procedure (SocketNum : cardinal) of object;
  tLspModuleState = procedure (state : byte) of object;

  TLSPModuleControl = class(TComponent)
  private
    fOnRecv,fOnSend: tOnSendOrRecv;
    fOnConnect:tOnConnect;
    fOnDisconnect:tOnDisconnect;
    fPathToLspModule : string;
    fLookFor:string;
    fonLspModuleState : tLspModuleState;
    fWasStarted : boolean; //true - ���� ���������� �������, ����� �����������.
    ShareClient : array[0..255] of TshareClient;
    ClientCount : integer;
    ShareMain : TshareMain;

    ReciverMEssageProcessThreadId: DWORD;
    ReciverMEssageProcessThreadHandle: THandle;
    ReciverWndClass:TWndClassEx; //������, ����� ������� �������� ���������� ��� ����� ���������� � ����� ������... ������ ����� ����.
    MutexHandle : THandle;

    Function setbuffer(SocketNum : cardinal; buffer : Tbuffer; len : word):integer;
    function FindIndexBySocketNum(SocketNum : cardinal):integer;
    Function CreateReciverWnd: Thandle;
    Procedure addclient(SocketNum : cardinal);
    Procedure deleteclient(SocketNum: cardinal);
    Procedure clientsend(SocketNum : cardinal);
    Procedure clientrecv(SocketNum : cardinal);
    procedure setlookfor(newLookFor:string);
    function isLspinstalled:boolean;

  public
    TmpBuff: Tbuffer;
    Function SendToServer(SocketNum : cardinal; buffer : Tbuffer; len : word):boolean;
    Function SendToClient(SocketNum : cardinal; buffer : Tbuffer; len : word):boolean;
    Procedure CloseSocket(SocketNum : cardinal);
    Procedure setlspstate(state: boolean);

  published
    property WasStarted:boolean read fWasStarted;
    property PathToLspModule:string read fPathToLspModule write fPathToLspModule;
    property isLspModuleInstalled:boolean read islspinstalled;
    
    property LookFor:string read fLookFor write setlookfor;
    property onLspModuleState:tLspModuleState read fonLspModuleState write fonLspModuleState;
    property onConnect:tOnConnect read fOnConnect write fOnConnect;
    property onDisconnect:tOnDisconnect read fOnDisconnect write fOnDisconnect;
    property onRecv:tOnSendOrRecv read fOnRecv write fOnRecv;
    property onSend:tOnSendOrRecv read fOnSend write fOnSend;
    constructor Create(AOwner: TComponent); override;
    destructor destroy; override;
  end;

  Tbuffer = array [0..$FFFF] of Byte;
var
  this_component : TLSPModuleControl;
  cs : RTL_CRITICAL_SECTION;
  Mmsg: MSG;  //���������

procedure Register;

implementation


procedure Register;
begin
  RegisterComponents('LSP', [TLSPModuleControl]);
end;



// ��������� ��������� ���������
function WindowProc (wnd: HWND; msg: integer; wparam: WPARAM; lparam: LPARAM):LRESULT;STDCALL;
begin

  result := 0;
  case msg of
  WM_action:
  begin
    case lparam of
    Action_client_connect:
      this_component.addclient(wparam);
    Action_client_disconnect:
      this_component.deleteclient(wparam);
    Action_client_send:
      this_component.clientsend(wparam);
    Action_client_recv:
      this_component.clientrecv(wparam);
  end;
  end;
  else
    Result := DefWindowProc(wnd,msg,wparam,lparam);
  end;
end;


procedure pReciverMessageProcess;
begin
  // ���� ��������� ���������}
  while GetMessage (Mmsg,0,0,0) do
  begin
    TranslateMessage (Mmsg);
    DispatchMessage (Mmsg);
  end;
end;

Function TLSPModuleControl.CreateReciverWnd;
begin
 //��� ��� �� ������� ������.
  ReciverWndClass.cbSize := sizeof (ReciverWndClass);
  with ReciverWndClass do
  begin
    lpfnWndProc := @WindowProc;
    cbClsExtra := 0;
    cbWndExtra := 0;
    hInstance := HInstance;
    lpszMenuName := nil;
    lpszClassName := Apendix;
  end;
  RegisterClassEx (ReciverWndClass);
  // �������� ���� �� ������ ���������� ������
  result := CreateWindowEx(0, Apendix, Apendix, WS_OVERLAPPEDWINDOW,0,0,0,0,0,0,Hinstance,nil);
end;

constructor TLSPModuleControl.create;
begin
  inherited Create(AOwner);
  fWasStarted := false; //�� ��� �� ����������.
  if csDesigning in self.ComponentState then exit;
  InitializeCriticalSection(cs);
  EnterCriticalSection(cs);
  //������� ������ ��������� ���� ����� �������� ��� �������� ���������� - ��������.
  MutexHandle := CreateMutex(nil, False, Mutexname);

  If (GetLastError = ERROR_ALREADY_EXISTS) then
    begin
      //�� ��� ����������....
      LeaveCriticalSection(cs);
      MessageBox(0, '������ ��������� TLSPModuleControl ��� ����������.'#10#13+
                    '����� �������� �� ����� ���� ������.', 'TLSPModuleControl', MB_OK);
      exit;
    end;

  ClientCount := 0;//���������� ��������� ��� � ��� ���� ��������

  //������� �������.
  ShareMain.MapHandle := CreateFileMapping(INVALID_HANDLE_VALUE, nil,
        PAGE_READWRITE, 0, SizeOf(TShareMapMain), Apendix);
  if ShareMain.MapHandle = 0 then
  ShareMain.MapHandle := OpenFileMapping(PAGE_READWRITE, false, Apendix);
  ShareMain.MapData := MapViewOfFile(ShareMain.MapHandle, FILE_MAP_ALL_ACCESS,
        0, 0, SizeOf(TShareMapMain));

  if ShareMain.MapHandle = 0 then
    begin
      setlspstate(false);
      MessageBox(0, '���������� �������� ������ � ������ ������� ������.'#10#13+
                    '����������� LSP ���������� ������������� �����'#10#13+
                    '������������� ������.', 'TLSPModuleControl', MB_OK);
      exit;    
    end;
  //������� ��������.
  ShareMain.MapData^.ReciverHandle := CreateReciverWnd;

  //������� �����, ������� ����� ������������ ��������� �� ���������
  ReciverMessageProcessThreadHandle := CreateThread(nil, 0, @pReciverMessageProcess, nil, 0, ReciverMEssageProcessThreadId);
  ResumeThread(ReciverMEssageProcessThreadHandle);

  //��������� � ����� ����������� ����� �������������
  ShareMain.MapData^.ProcessesForHook := flookfor;
  fWasStarted := true; //�� ���������� �������.
  LeaveCriticalSection(cs);
  this_component := self;
end;

destructor TLSPModuleControl.destroy;
begin
  if WasStarted then
    begin
      ReleaseMutex(MutexHandle); //���� ��������. (�� ��� �� ��������).
      CloseHandle(MutexHandle);
      TerminateThread(ReciverMEssageProcessThreadHandle, 0); //������ ���� � ���������� ���������
      DestroyWindow(ShareMain.MapData^.ReciverHandle); //������� ���� ��������
      ShareMain.MapData^.ReciverHandle := 0;
      windows.UnregisterClass(apendix, HInstance);
    end;
  inherited destroy;
end;


procedure TLSPModuleControl.addclient;
var
  hook:boolean;
begin
  //�������������
  ShareClient[ClientCount].SocketNum := SocketNum;

  //���������� ������� ��� ������� (������ ���� ������ � ���)
  ShareClient[ClientCount].MapHandle := CreateFileMapping(INVALID_HANDLE_VALUE, nil,
        PAGE_READWRITE, 0, SizeOf(TShareMapClient), pchar(Apendix + inttostr(SocketNum)));
  ShareClient[ClientCount].MapData := MapViewOfFile(ShareClient[ClientCount].MapHandle, FILE_MAP_ALL_ACCESS,
        0, 0, SizeOf(TShareMapClient));
  hook := true;
  if assigned(onConnect) then
    onConnect(SocketNum, ShareClient[ClientCount].MapData^.ip, ShareClient[ClientCount].MapData^.port,ShareClient[ClientCount].MapData^.application,ShareClient[ClientCount].MapData^.pid,hook);
  //���� ������ ���� ������ ?
  if hook then
  begin
    //���� �� - ������� ������� � ����������� ���--�� ������� �� 1.
    ShareClient[ClientCount].MapData.hookithandle := CreateMutex(nil, false, pchar(Mutexname+inttostr(SocketNum)));

    //����������� ���-�� ������� �� 1.
    Inc(ClientCount);
  end
  else //�� ���� ? �������� ������ �� �������. ����� � ��������.
  begin
    ShareClient[ClientCount].MapData := nil;
    ShareClient[ClientCount].MapHandle := 0;
    ShareClient[ClientCount].SocketNum := 0;
  end;
end;

procedure TLSPModuleControl.deleteclient;
var
  i : integer;
begin
  i := 0;
  //����� ���� �� ������� ��� sockid; ��� �� ������� -)
  while (i < ClientCount) and (ShareClient[i].SocketNum <> SocketNum) do
    inc(i);

  if i = ClientCount then //�� ����� -)... ���������� �������.. -)
    exit;

  //����������� �������
  if ShareClient[i].MapData <> nil then
    begin
    ReleaseMutex(ShareClient[i].MapData.hookithandle);
    CloseHandle(ShareClient[i].MapData.hookithandle)
    end;

  //������ ������� ���� ���� ������
  inc(i);

  //� �������� ��� ������������� ������.
  while i < ClientCount do
    begin
      ShareClient[i-1] := ShareClient[i];
      inc(i);
    end;
  ShareClient[ClientCount].MapData.hookithandle := CreateMutex(nil, false, pchar(Mutexname+inttostr(SocketNum)));

  if assigned(onDisconnect) then
    onDisconnect(SocketNum);
        
  // -1 ������������
  Dec(ClientCount);
end;

function TLSPModuleControl.FindIndexBySocketNum;
begin
  result := 0;
  //����� ���� �� ������� ��� sockid; ��� �� ������� -)
  while (result < ClientCount) and (ShareClient[result].SocketNum <> SocketNum) do
    inc(result);

  if Result = ClientCount then Result := -1;

end;

procedure TLSPModuleControl.clientrecv(SocketNum: cardinal);
var
  index : integer;
begin
  index := FindIndexBySocketNum(SocketNum);
  if index = -1 then exit; //� ��� ��� ��� ����!?..�? ������!!!

  if Assigned(onRecv) then
    onRecv(SocketNum, ShareClient[index].MapData^.buff, ShareClient[index].MapData^.buffersize);

  //������ ����������. � ��� ���� ��� ���� �����.

{    if (ShareClient[index].MapData^.toclientbuffer.buffsize > 0) then
      try
        //���� �� �������� ������ � ��� ����������� ������ ��
        offset := ShareClient[index].MapData^.toclientbuffer.buffsize;
        //� ������� ������ ��������
        cursize := ShareClient[index].MapData^.buffersize;
        //��� ���� ������ ������ ��������
        inc(ShareClient[index].MapData^.buffersize, offset);
        //� ���������� ����� ������ ������� � ����
        ShareClient[index].MapData^.toclientbuffer.buffsize := 0;

      //������� �� �����
        move(ShareClient[index].MapData^.Buff[0],
             ShareClient[index].MapData^.Buff[offset],
             cursize);

        //� � ������ ������ ��������� ������
        move(ShareClient[index].MapData^.toclientbuffer.Buff[0],
             ShareClient[index].MapData^.Buff[0],
             offset);
      except
      end     }
end;

procedure TLSPModuleControl.clientsend(SocketNum: cardinal);
var
  index : integer;
begin
  index := FindIndexBySocketNum(SocketNum);
  if index = -1 then exit; //� ��� ��� ��� ����!?.. ���������� �����!!!
  if Assigned(onSend) then
    onSend(SocketNum, ShareClient[index].MapData^.buff, ShareClient[index].MapData^.buffersize);
end;

//���������� ������ �� ����� ������� ������������� �������� ����� ������
function TLSPModuleControl.SendToServer;
var
  index : integer;
begin
  index := setbuffer(SocketNum, buffer, len);
  Result := (index >= 0);
  if not Result then
    exit;

  SendMessage(ShareClient[index].MapData^.ReciverHandle, WM_action, SocketNum, Action_sendtoserver);
end;

//���������� ������ ������� ������������� �������� ����� ������
function TLSPModuleControl.SendToClient;
var
  index : integer;
begin
  index := FindIndexBySocketNum(SocketNum);
  Result := (index >= 0);
  if not Result then
    exit;

  //��������� � ���������� ���� ������
  Move(buffer, ShareClient[index].MapData^.toclientbuffer.Buff[ShareClient[index].MapData^.toclientbuffer.buffsize], len);
  //� ����������� �� �����
  inc(ShareClient[index].MapData^.toclientbuffer.buffsize, len);
end;

//���������� ������ � ������� ������������ �� ������������ ������� ������
function TLSPModuleControl.setbuffer;
begin
  result := FindIndexBySocketNum(SocketNum);
  if Result = -1 then exit;

  FillChar(ShareClient[result].MapData^.Buff, $ffff, #0);
  CopyMemory(
    @ShareClient[result].MapData^.Buff[0],
    @buffer[0],
    len);
    
  ShareClient[result].MapData^.buffersize := len;
end;

procedure TLSPModuleControl.setlookfor(newLookFor: string);
begin
fLookFor := newLookFor;
if ShareMain.MapData <> nil then
  ShareMain.MapData^.ProcessesForHook := flookfor;
end;

function TLSPModuleControl.islspinstalled: boolean;
begin
result := isinstalled;
end;

Procedure TLSPModuleControl.setlspstate(state: boolean);
var
  result : byte;
begin
  if state then
    result := InstallProvider(fPathToLspModule)
  else
    result := RemoveProvider;

if assigned(onLspModuleState) then
  onLspModuleState(result);

end;

procedure TLSPModuleControl.CloseSocket(SocketNum: cardinal);
var
 index: integer;
begin
  index := FindIndexBySocketNum(SocketNum);
  if index = -1 then exit;
  SendMessage(ShareClient[index].MapData^.ReciverHandle, WM_action, SocketNum, Action_closesocket);
end;

end.
