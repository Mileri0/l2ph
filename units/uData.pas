unit uData;

interface

uses
  uResourceStrings,
  uGlobalFuncs,
  SysUtils,
  Classes,
  Forms,
  Dialogs,
  Graphics, 
  LSPControl,
  ExtCtrls,
  windows,
  ComCtrls,
  math,
  uencdec,
  usharedstructs,
  uVisualContainer,
  uSocketEngine,
  uUserForm,
  StrUtils,
  Variants,
  JvHLEditor,
  SyncObjs,
  fs_iinterpreter, fs_ipascal, fs_iinirtti, fs_imenusrtti, fs_idialogsrtti,
  fs_iextctrlsrtti, fs_iformsrtti, fs_iclassesrtti;

type
  TlspConnection = class (tobject)
    Visual: TfVisual;
    AssignedTabSheet : TTabSheet;
    EncDec : TEncDec;
    SocketNum : integer;
  public
    active : boolean;
    RawLog : TMemoryStream;
    isRawAllowed:boolean;
    tempbufferRecv, tempbufferSend : array [0..$ffff] of byte;
    TempBufferRecvLen, TempBufferSendLen :cardinal;
    mustbedestroyed: boolean;
    DisconnectAfterDestroy : boolean;
    noFreeAfterDisconnect: boolean;
    procedure NewAction(action : byte; Caller: TObject);
    procedure NewPacket(var Packet:Tpacket;FromServer: boolean; Caller: TObject);
    constructor create(SocketN:integer);
    Procedure   INIT;
    destructor  destroy; override;
    Procedure AddToRawLog(dirrection : byte; var data; size:word);
  end;

  TpacketLogWiev = class (TObject)
    Visual: TfVisual;
    AssignedTabSheet : TTabSheet;
    MustBeDestroyed : boolean;
    sFileName:string;
  public
    constructor create;
    Procedure   INIT(Filename:string);
    destructor  destroy; override;
  end;
  
  TdmData = class(TDataModule)
    LSPControl: TLSPModuleControl;
    timerSearchProcesses: TTimer;
    fsClassesRTTI1: TfsClassesRTTI;
    fsFormsRTTI1: TfsFormsRTTI;
    fsExtCtrlsRTTI1: TfsExtCtrlsRTTI;
    fsDialogsRTTI1: TfsDialogsRTTI;
    fsMenusRTTI1: TfsMenusRTTI;
    fsIniRTTI1: TfsIniRTTI;
    procedure LSPControlConnect(SocketNum: Cardinal; ip: String;
      port: Cardinal; exename: String; pid: Cardinal; hook: Boolean);
    procedure LSPControlDisconnect(SocketNum: Cardinal);
    procedure LSPControlLspModuleState(state: Byte);
    procedure timerSearchProcessesTimer(Sender: TObject);
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
    procedure LSPControlRecv(SocketNum: Cardinal; var buffer: Tbuffer;
      var len: Cardinal);
    procedure LSPControlSend(SocketNum: Cardinal; var buffer: Tbuffer;
      var len: Cardinal);
  private
    CriticalSection  : TCriticalSection;
    { Private declarations }
  public
    function FindLspConnectionBySockNum(SockNum:integer):TlspConnection;
    procedure destroyDeadLSPConnections;
    procedure destroyDeadLogWievs;
    procedure encryptAndSend(CurrentLsp:TlspConnection; Packet: Tpacket; ToServer: Boolean);
    procedure RefreshPrecompile(var fsScript: TfsScript);
    function CallMethod(Instance: TObject; ClassType: TClass; const sMethodName: String; var Params: Variant): Variant;


    procedure SendPacket(Packet: Tpacket; tid: integer; ToServer: Boolean);
    procedure SendPacketToName(Packet: Tpacket; cName: string; ToServer: Boolean);
    function ConnectNameById(id:integer):string;
    function ConnectIdByName(cname:string):integer;
    procedure SetConName(Id:integer; Name:string);
    
              //����������� �������� :)
    Procedure setNoDisconnectOnDisconnect(id:integer; NoFree:boolean;IsServer:boolean);
    Procedure setNoFreeOnConnectionLost(id:integer; NoFree:boolean);
    procedure DoDisconnect(id:integer);
    function Compile(var fsScript: TfsScript; var JvHLEditor: TJvHLEditor; var StatBat:TStatusBar): Boolean;
  end;

var
  dmData: TdmData;
  Processes :TStringList;
  LSPConnections, PacketLogWievs:Tlist;
  sockEngine : TSocketEngine;

implementation
uses uscripts, uPluginData, uPlugins, umain, uSettingsDialog, uProcesses, advApiHook;

{$R *.dfm}

{ TdmData }


procedure TdmData.LSPControlConnect(SocketNum: Cardinal; ip: String;
  port: Cardinal; exename: String; pid: Cardinal; hook: Boolean);
var
  str : string;
  i : integer;
  newlspconnection : TlspConnection;
begin

  hook := (Pos(IntToStr(port)+';',sIgnorePorts+';')=0);
  if hook then
    str := rsLSPConnectionWillbeIntercepted
  else
    str := rsLSPConnectionWillbeIgnored;
  if hook then
    begin
      newlspconnection := TlspConnection.create(SocketNum);
      newlspconnection.INIT;      

      //���������� �������
      for i:=0 to Plugins.Count - 1 do with TPlugin(Plugins.Items[i]) do
      if Loaded  then
      begin
        if Assigned(OnConnect) then OnConnect(SocketNum, true);
        if Assigned(OnConnect) then OnConnect(SocketNum, false);
      end;
    end;
  AddToLog(Format(rsLSPConnectionDetected, [SocketNum, ip, port, str]));
end;

procedure TdmData.LSPControlDisconnect(SocketNum: Cardinal);
var
  connection : TlspConnection;
  i : integer;
  
begin
  CriticalSection.Enter;

  //���������� �������
  for i:=0 to Plugins.Count - 1 do with TPlugin(Plugins.Items[i]) do
  if Loaded  then
  begin
    if Assigned(OnDisconnect) then OnDisconnect(SocketNum, true);
    if Assigned(OnDisconnect) then OnDisconnect(SocketNum, false);
  end;


  connection := FindLspConnectionBySockNum(SocketNum);
  if assigned(connection) then
    if not connection.noFreeAfterDisconnect then
      begin
        connection.SocketNum := 0;
        connection.active := false;
        connection.destroy;
      end
    else
    begin
      connection.Visual.ThisOneDisconnected;
      connection.active := false;
    end;
  AddToLog(Format(rsLSPDisconnectDetected, [SocketNum]));
  CriticalSection.Leave;
end;

procedure TdmData.LSPControlLspModuleState(state: Byte);
begin
  case state of
  LSP_Install_success:      AddToLog(rsLSP_Install_success);//�� �����������
  LSP_Already_installed:    AddToLog(rsLSP_Already_installed);
  LSP_Uninstall_success:    AddToLog(rsLSP_Uninstall_success);
  LSP_Not_installed:        ;//AddToLog(rsLSP_Not_installed);
  LSP_Install_error:
                            begin //������ ��������� �� �� �����.
                              fSettings.isLSP.Enabled := true;
                              fSettings.ChkLSPIntercept.Checked := false;
                              AddToLog(rsLSP_Install_error)
                            end;
  LSP_UnInstall_error:
                            begin //������ ����� ���� �� �� �����.
                              fSettings.isLSP.Enabled := false;
                              fSettings.ChkLSPIntercept.Checked := true;
                              AddToLog(rsLSP_UnInstall_error)
                            end;
  LSP_Install_error_badspipath:
                            begin //������ ��������� �� �� �����.
                              fSettings.isLSP.Enabled := true;
                              fSettings.ChkLSPIntercept.Checked := false;
                              AddToLog(rsLSP_Install_error_badspipath)
                            end;
  end;
end;

procedure TdmData.timerSearchProcessesTimer(Sender: TObject);
var
  tmp: TStrings;
  i,k: Integer;
  cc: Cardinal;
  ListSearch: string; // ������ ��������� ������� ����� ������
begin

  if isDestroying then exit;
  try
  tmp:=TStringList.Create;
  ListSearch := ';'+LowerCase(sClientsList); // � ������ �������
  // ������� ��� �������
  ListSearch := StringReplace (ListSearch, ' ', '', [rfReplaceAll]);
  // �������� ���� ������������ ���������� ,  ������ �� �� ;
  // � ��������� � ����� ������ ;  � ������ �� ��� �� �������� � ��� ���� ��� ���,
  // �� ������� �� ��������
  ListSearch := StringReplace (ListSearch, ',', ';', [rfReplaceAll])+';';

  GetProcessList(tmp);
  for i:=0 to tmp.Count-1 do begin
    // ������ ��������� �� ���������� ��������� (tmp.Count <> ListBox1.Items.Count)
    // �������� ���� ���� ���� ���������������
    if (fProcesses.FoundProcesses.Items.IndexOf(tmp.ValueFromIndex[i]+' ('+tmp.Names[i]+')')=-1) then begin
      fProcesses.FoundProcesses.Items.Clear;
      fProcesses.FoundClients.Items.Clear;
      for k := 0 to tmp.Count - 1 do begin
        // ��������� � ���� ��������� ���������
        fProcesses.FoundProcesses.Items.Add(tmp.ValueFromIndex[k]+' ('+tmp.Names[k]+')');
        //���������� ��������� ��������� �� ������� ����������� ��������
        if AnsiPos(';'+tmp.ValueFromIndex[k]+';', ListSearch) > 0  then
        begin
          if fSettings.ChkIntercept.Checked and (Processes.Values[tmp.Names[k]]='') then begin
            Processes.Values[tmp.Names[k]]:='error';
            cc := OpenProcess(PROCESS_ALL_ACCESS,False,StrToInt(tmp.Names[k]));
            case fSettings.HookMethod.ItemIndex of
              0: begin
                if InjectDll(cc, PChar(ExtractFilePath(ParamStr(0))+fSettings.isInject.Text)) then begin
                  Processes.Values[tmp.Names[k]]:='ok';
                  AddToLog (format(rsClientPatched0, [tmp.ValueFromIndex[k], tmp.Names[k]]));
                end;
              end;
              1: begin
                if InjectDllEx(cc, pInjectDll) then begin
                  Processes.Values[tmp.Names[k]]:='ok';
                  AddToLog (format(rsClientPatched1, [tmp.ValueFromIndex[k], tmp.Names[k]]));
                end;
              end;
              2: begin
                if InjectDllAlt(cc, PChar(ExtractFilePath(ParamStr(0))+fSettings.isInject.Text)) then begin
                  Processes.Values[tmp.Names[k]]:='ok';
                  AddToLog (format(rsClientPatched2, [tmp.ValueFromIndex[k], tmp.Names[k]]));
                end;
              end;
            end;
            CloseHandle(cc);
          end;
          fProcesses.FoundClients.Items.Add(tmp.ValueFromIndex[k]+' ('+tmp.Names[k]+') '+Processes.Values[tmp.Names[k]]);
        end;
      end;
    end;
  end;
  finally
  tmp.Free;
  end;
end;

procedure TdmData.DataModuleCreate(Sender: TObject);
begin
  Processes:=TStringList.Create;
  LSPConnections := TList.Create;
  CriticalSection  := TCriticalSection.create;
  PacketLogWievs := TList.Create;
  
end;

procedure TdmData.DataModuleDestroy(Sender: TObject);
begin
  Processes.Free;
  while LSPConnections.Count > 0 do
    TlspConnection(LSPConnections.Items[0]).destroy;
  while PacketLogWievs.Count > 0 do
    TpacketLogWiev(PacketLogWievs.Items[0]).destroy;

  LSPConnections.Destroy;
  PacketLogWievs.Destroy;
  CriticalSection.destroy;
end;



{ TlspVisual }

procedure TlspConnection.AddToRawLog(dirrection: byte; var data;
  size: word);
var
  dtime: Double;
begin
  if not isRawAllowed then exit;
  RawLog.WriteBuffer(dirrection,1);
  RawLog.WriteBuffer(size,2);
  dtime := now;
  RawLog.WriteBuffer(dtime,8);
  RawLog.WriteBuffer(data,size);
end;

constructor TlspConnection.create;
begin
  LSPConnections.Add(self);
  RawLog := TMemoryStream.Create;
  isRawAllowed := GlobalRawAllowed;
  SocketNum := SocketN;
  TempBufferSendLen := 0;
  TempBufferRecvLen := 0;
  mustbedestroyed := false;
  DisconnectAfterDestroy := false;
  EncDec := TencDec.create;
  EncDec.Ident := SocketNum;
  EncDec.ParentTtunel := nil;
  EncDec.ParentLSP := self;
  EncDec.Settings := GlobalSettings;
end;

destructor TlspConnection.destroy;
var
  i : integer;
begin
  i := 0;
  while i < LSPConnections.Count do
    begin
      if LSPConnections.Items[i] = self then
        begin
          LSPConnections.Delete(i);
          break;
        end;
        inc(i);
    end;

  if DisconnectAfterDestroy then
    if SocketNum <> 0 then
      dmData.LSPControl.CloseSocket(SocketNum);
  if Assigned(visual) then
    begin
      Visual.deinit;
      Visual.Destroy;
    end;
  EncDec.destroy;
  if Assigned(AssignedTabSheet) then
    AssignedTabSheet.Destroy;
  RawLog.Destroy;
  inherited;
end;

procedure TlspConnection.INIT;
begin
  EncDec.onNewAction := NewAction;
  EncDec.onNewPacket := NewPacket;
  EncDec.init;
  AssignedTabSheet := TTabSheet.Create(L2PacketHackMain.pcClientsConnection);
  Visual := TfVisual.Create(AssignedTabSheet);
  Visual.currenttunel := nil;
  Visual.CurrentTpacketLog := nil;
  Visual.Parent := AssignedTabSheet;
  Visual.setNofreeBtns(GlobalNoFreeAfterDisconnect);
  noFreeAfterDisconnect := GlobalNoFreeAfterDisconnect;
  AssignedTabSheet.PageControl := L2PacketHackMain.pcClientsConnection;
  AssignedTabSheet.Caption := '[lsp]#'+inttostr(SocketNum);
  if not L2PacketHackMain.pcClientsConnection.Visible then L2PacketHackMain.pcClientsConnection.Visible  := true;
  Visual.currentLSP := self;
  Visual.init;
  active := true;
end;

procedure TlspConnection.NewAction(action: byte; Caller: TObject);
var
  encdec : TencDec;
  lspConnection : TlspConnection;

begin
case action of
  TencDec_Action_GotName:
    begin
      EncDec := TencDec(caller);
      LspConnection := nil;
      if assigned(EncDec.ParentLSP) then
        lspConnection := TlspConnection(EncDec.ParentLSP);
      if assigned(LspConnection) then
        LspConnection.AssignedTabSheet.Caption := EncDec.CharName;
    end; //������ � name; ���������� - UpdateComboBox1 (������� �������������)

end;
  //SendMessage(L2PacketHackMain.Handle,WM_NewAction,integer(action),integer(caller));
end;

procedure TlspConnection.NewPacket(var Packet:Tpacket;FromServer: boolean; Caller: TObject);
begin
  fScript.ScryptProcessPacket(packet, FromServer, TencDec(Caller).Ident); //�������� �������� � ��������
  if Packet.Size > 2 then //������� ���� ������� ����� ��������
  Visual.AddPacketToAcum(Packet, FromServer, Caller);
  { TODO : here }

  //��.. � ������� �� �������..
  PostMessage(L2PacketHackMain.Handle, WM_ProcessPacket,integer(pointer(tfvisual(ttunel(TencDec(Caller).ParentTtunel).Visual))),integer(@packet));
end;


procedure TdmData.LSPControlRecv(SocketNum: Cardinal; var buffer: Tbuffer;
  var len: Cardinal);

var
  LspConnection : TlspConnection;
  PcktLen : Word;
  ResultBuff : Tbuffer;
  ResultLen : cardinal;
  tmppack:tpacket;
begin

  CriticalSection.Enter;
  LspConnection := FindLspConnectionBySockNum(SocketNum);
  if LspConnection = nil then exit;
    LspConnection.AddToRawLog(PCK_GS_ToClient, buffer[0], len);
  

  ResultLen := 0;
  FillChar(ResultBuff,$ffff,#0);
  //���������� ��� ����������� ������ �� ��������� ������ (������ �������������� ������)
  Move(buffer,LspConnection.tempbufferRecv[LspConnection.TempBufferRecvLen], len);
  inc(LspConnection.TempBufferRecvLen, len);

  //�������� ������ ������ ����������� � ��������� ������
  Move(LspConnection.TempBufferRecv[0], PcktLen, 2);

  //���� � ��� ������� ������ � ������� ����� �������� ����� ��������� - ������������ �����
  while (LspConnection.TempBufferRecvLen >= PcktLen) and (PcktLen > 0) and (LspConnection.TempBufferRecvLen > 2) do
  begin
    //��������� ������ � ���������� ������� � ��������� ������ �� ��������� 
    Move(LspConnection.TempBufferRecv[0], tmppack.PacketAsCharArray[0], PcktLen);
    //�������� ������ � ��������� ������� ������ ��������� ������
    move(LspConnection.TempBufferRecv[PcktLen], LspConnection.TempBufferRecv[0], LspConnection.TempBufferRecvLen);
    dec(LspConnection.TempBufferRecvLen, PcktLen);
    //������������ �����
    LspConnection.EncDec.DecodePacket(tmppack, PCK_GS_ToClient);
    LspConnection.EncDec.EncodePacket(tmppack, PCK_GS_ToClient);


    //���������� ����������� �� ��������� �������������� ������
    Move(tmppack.PacketAsCharArray[0],  ResultBuff[ResultLen], tmppack.Size);
    //����������� ������� ���������� ��������������� �������
    inc(ResultLen, tmppack.Size);

    if LspConnection.TempBufferRecvLen > 2 then
      //�������� ������ ������ ����������� � ��������� ������
      Move(LspConnection.TempBufferRecv[0], PcktLen, 2)
    else
      PcktLen := 0;
  end;

  //� ����� � ��� ���������� �������������� ������
  buffer := ResultBuff;
  len := ResultLen;
  CriticalSection.Leave;
end;

function TdmData.FindLspConnectionBySockNum(SockNum: integer): TlspConnection;
var
  i : integer;
begin
i := 0;
while i < LSPConnections.Count do
  begin
    if TlspConnection(LSPConnections.Items[i]).SocketNum = SockNum then break;
    inc(i);
  end;

  if i = LSPConnections.Count then
    Result := nil
  else
    Result := TlspConnection(LSPConnections.Items[i]);
end;

procedure TdmData.LSPControlSend(SocketNum: Cardinal; var buffer: Tbuffer;
  var len: Cardinal);
var
  LspConnection : TlspConnection;
  PcktLen : Word;
  ResultBuff : Tbuffer;
  ResultLen : cardinal;
  tmppack:tpacket;
begin
  CriticalSection.Enter;
  LspConnection := FindLspConnectionBySockNum(SocketNum);
  if LspConnection = nil then exit;
  LspConnection.AddToRawLog(PCK_GS_ToServer, buffer[0], len);

  ResultLen := 0;
  FillChar(ResultBuff,$ffff,#0);
  //���������� ��� ����������� ������ �� ��������� ������ (������ �������������� ������)
  Move(buffer,LspConnection.tempbufferSend[LspConnection.TempBufferSendLen], len);
  inc(LspConnection.TempBufferSendLen, len);

  //�������� ������ ������ ����������� � ��������� ������
  Move(LspConnection.TempBufferSend[0], PcktLen, 2);

  //���� � ��� ������� ������ � ������� ����� �������� ����� ��������� - ������������  ���������
  while (LspConnection.TempBufferSendLen >= PcktLen) and (PcktLen > 0) and (LspConnection.TempBufferSendLen > 2) do
  begin
    //��������� ������ � ���������� ������� � ��������� ������ �� ��������� 
    Move(LspConnection.TempBufferSend[0], tmppack.PacketAsCharArray[0], PcktLen);
    //�������� � ��������� ������� ������ ��������� ������
    move(LspConnection.TempBufferSend[PcktLen], LspConnection.TempBufferSend[0], LspConnection.TempBufferSendLen);
    dec(LspConnection.TempBufferSendLen, PcktLen);

    //������������ �����
    LspConnection.EncDec.DecodePacket(tmppack, PCK_GS_ToServer);
    LspConnection.EncDec.EncodePacket(tmppack, PCK_GS_ToServer);

    //���������� ����������� �� ��������� �������������� ������
    Move(tmppack.PacketAsCharArray[0], ResultBuff[ResultLen], tmppack.Size);
    //����������� ������� ���������� ��������������� �������
    inc(ResultLen, tmppack.Size);

    if LspConnection.TempBufferSendLen > 2 then
    //�������� ������ ������ ����������� � ��������� ������
    Move(LspConnection.TempBufferSend[0], PcktLen, 2)
    else
      PcktLen := 0;
  end;

  //� ����� � ��� ���������� �������������� ������
  buffer := ResultBuff;
  len := ResultLen;
  CriticalSection.Leave;
end;


procedure TdmData.destroyDeadLspConnections;
var
  i: integer;
begin
  if not Assigned(LSPConnections) then exit;

  i := 0;
  while i < LSPConnections.Count do
  begin
    if TlspConnection(LSPConnections.Items[i]).MustBeDestroyed then
    begin
      TlspConnection(LSPConnections.Items[i]).destroy;
      break;
    end
    else
    inc(i);
  end;
end;

procedure TdmData.encryptAndSend;
var
  s : integer;
  Dirrection : byte;
begin
  CriticalSection.Enter;
  //��������
  if ToServer then
    Dirrection := PCK_GS_ToServer
  else
    Dirrection := PCK_GS_ToClient;
  currentLSP.EncDec.EncodePacket(packet, Dirrection);

  //���������� � ������ ����������� � ������
  FillChar(dmData.LSPControl.tmpbuff, $ffff, #0);


  Move(Packet.PacketAsByteArray[0], dmData.LSPControl.tmpbuff[0], Packet.Size);
  
  //�������� ����� ������
  s := TlspConnection(currentLSP).SocketNum;


  if ToServer then
    dmData.LSPControl.SendToServer(s, dmData.LSPControl.tmpbuff, Packet.Size)
  else
    //exit;{ TODO : ��������� ����, ������� }
    dmData.LSPControl.SendToClient(s, dmData.LSPControl.tmpbuff, Packet.Size);
  CriticalSection.Leave;
end;



procedure TdmData.RefreshPrecompile(var fsScript: TfsScript);
var
  fss: string;
  i,k: Integer;
  funcs: TStringArray;
begin
  fss:='fss:integer='+IntToStr(Integer(fsScript));
  fsScript.Clear;
  fsScript.AddRTTI;

  // ��������� �������� �������� ���� ������� � �������

  for i:=0 to Plugins.Count - 1 do
  with TPlugin(Plugins.Items[i]) do
  if Loaded and Assigned(OnRefreshPrecompile) then begin
    SetLength(funcs,0);
    k := OnRefreshPrecompile(funcs);
    if k>0 then for k:=0 to High(funcs) do
      fsScript.AddMethod(funcs[k],CallMethod);
  end;
  

  fsScript.AddMethod('function HStr(Hex:String):String',CallMethod);
  fsScript.AddMethod('procedure SendToClient('+fss+')',CallMethod);
  fsScript.AddMethod('procedure SendToServer('+fss+')',CallMethod);
  fsScript.AddMethod('procedure SendToClientEx(CharName:string;'+fss+')',CallMethod);
  fsScript.AddMethod('procedure SendToServerEx(CharName:string;'+fss+')',CallMethod);
  fsScript.AddMethod('procedure NoCloseFrameAfterDisconnect('+fss+')',CallMethod);
  fsScript.AddMethod('procedure CloseFrameAfterDisconnect('+fss+')',CallMethod);
  fsScript.AddMethod('procedure NoCloseClientAfterServerDisconnect('+fss+')',CallMethod);
  fsScript.AddMethod('procedure CloseClientAfterServerDisconnect('+fss+')',CallMethod);
  fsScript.AddMethod('procedure NoCloseServerAfterClientDisconnect('+fss+')',CallMethod);
  fsScript.AddMethod('procedure CloseServerAfterClientDisconnect('+fss+')',CallMethod);
  fsScript.AddMethod('procedure Disconnect('+fss+')',CallMethod);
  fsScript.AddMethod('function ConnectNameByID(id:integer;'+fss+'):string',CallMethod);
  fsScript.AddMethod('function ConnectIDByName(name:string;'+fss+'):integer',CallMethod);
  fsScript.AddMethod('procedure SetName(Name:string;'+fss+')',CallMethod);
  fsScript.AddMethod('procedure Delay(msec: Cardinal)',CallMethod);
  fsScript.AddMethod('procedure ShowForm',CallMethod);
  fsScript.AddMethod('procedure HideForm',CallMethod);
  fsScript.AddMethod('procedure WriteS(v:string;'+fss+')',CallMethod);
  fsScript.AddMethod('procedure WriteC(v:byte; ind:integer=0;'+fss+')',CallMethod);
  fsScript.AddMethod('procedure WriteD(v:integer; ind:integer=0;'+fss+')',CallMethod);
  fsScript.AddMethod('procedure WriteH(v:word; ind:integer=0;'+fss+')',CallMethod);
  fsScript.AddMethod('procedure WriteF(v:double; ind:integer=0;'+fss+')',CallMethod);
  fsScript.AddMethod('function ReadS(var index:integer;'+fss+'):string',CallMethod);
  fsScript.AddMethod('function ReadC(var index:integer;'+fss+'):byte',CallMethod);
  fsScript.AddMethod('function ReadD(var index:integer;'+fss+'):integer',CallMethod);
  fsScript.AddMethod('function ReadH(var index:integer;'+fss+'):word',CallMethod);
  fsScript.AddMethod('function ReadF(var index:integer;'+fss+'):double',CallMethod);
  fsScript.AddMethod('function LoadLibrary(LibName:String):Integer',CallMethod);
  fsScript.AddMethod('function FreeLibrary(LibHandle:Integer):Boolean',CallMethod);
  //for support DLL
  fsScript.AddMethod('function StrToHex(str1:String):String;',CallMethod);
  fsScript.AddMethod('procedure CallPr(LibHandle:integer;FunctionName:String;Count:Integer;Params:array of variant)',CallMethod);
  fsScript.AddMethod('function CallFnc(LibHandle:integer;FunctionName:String;Count:Integer;Params:array of variant):string',CallMethod);
  fsScript.AddMethod('procedure TestFunc(LibHandle:integer;FunctionName:String;Count:Integer)',CallMethod);
  fsScript.AddMethod('procedure TestFunc1(LibHandle:integer;FunctionName:String;Count1:variant)',CallMethod);
  //for support DLL
  fsScript.AddMethod('function CallFunction(LibHandle:integer;FunctionName:String;Count:Integer;Params:array of variant):variant',CallMethod);
  // �������������� ����� ���������
  fsScript.AddMethod('function CallSF(ScriptName:String;FunctionName:String;Params:array of variant):variant',CallMethod);
  fsScript.AddMethod('procedure sendMSG(msg:String;)',CallMethod);

  fsScript.AddForm(UserForm);
  fsScript.AddVariable('buf','String','');
  fsScript.AddVariable('pck','String','');
  fsScript.AddVariable('FromServer','Boolean',True);
  fsScript.AddVariable('FromClient','Boolean',False);
  fsScript.AddVariable('ConnectID','Integer',0);
  fsScript.AddVariable('ConnectName','String','');
end;



function TdmData.CallMethod(Instance: TObject; ClassType: TClass;
  const sMethodName: String; var Params: Variant): Variant;
var
  buf,pct,tmp: string;
  temp: WideString;
  d: Integer;
  ConId:integer;
  b: byte;
  h: Word;
  f: Double;
  LibHandle:Pointer;
  Count:Integer;
  Par:array of Pointer;
  List:variant;
  i:integer;
  Res:Integer;
  //support DLL
  popa:array of PChar;
  count1:pchar;
  TestFunc: function (ar:array of PChar):Pchar;stdcall;
  TestProc: procedure (ar:array of PChar);stdcall;
  tstFunc1: procedure (ar:pchar);
  tstFunc: procedure (ar:integer);
  packet:TPacket;
  SelectedScript:tscript;
  //support DLL
begin
  // ������� ��� ����������� �������� ���������� �������
  for i:=0 to Plugins.Count - 1 do
    with TPlugin(Plugins.Items[i]) do
      if Loaded and Assigned(OnCallMethod) then
        if OnCallMethod(sMethodName, Params, Result) then Exit;
 
  // ���� ������� �� ���������� �� ������������ ����  
  if sMethodName = 'SENDTOCLIENT' then begin
    buf:=TfsScript(Integer(Params[0])).Variables['buf'];
    ConId:=TfsScript(Integer(Params[0])).Variables['ConnectID'];
    packet.Size := Length(buf)+2;
    Move(buf[1], packet.Data[0], Length(buf));
    SendPacket(packet, ConId, False);
  end else
  if sMethodName = 'SENDTOSERVER' then begin
    buf:=TfsScript(Integer(Params[0])).Variables['buf'];
    ConId:=TfsScript(Integer(Params[0])).Variables['ConnectID'];
    packet.Size := Length(buf)+2;
    Move(buf[1], packet.Data[0], Length(buf));
    SendPacket(packet, ConId, true);
  end else
  if sMethodName = 'SENDTOCLIENTEX' then begin
    buf:=TfsScript(Integer(Params[1])).Variables['buf'];
    packet.Size := Length(buf)+2;
    Move(buf[1], packet.Data[0], Length(buf));
    SendPacketToName(packet, string(Params[0]), False);
  end else
  if sMethodName = 'SENDTOSERVEREX' then begin
    buf:=TfsScript(Integer(Params[1])).Variables['buf'];
    packet.Size := Length(buf)+2;
    Move(buf[1], packet.Data[0], Length(buf));
    SendPacketToName(packet, string(Params[0]), True);
  end else
  if sMethodName = 'READC' then begin
    pct:=TfsScript(Integer(Params[1])).Variables['pck'];
    if Integer(Params[0])<=Length(pct) then b:=Byte(pct[Integer(Params[0])])
    else b:=0;
    Params[0]:=Integer(Params[0])+1;
    Result:=b;
  end else
  if sMethodName = 'READD' then begin
    pct:=TfsScript(Integer(Params[1])).Variables['pck'];
    if Integer(Params[0])<Length(pct)-2 then Move(pct[Integer(Params[0])],d,4);
    Params[0]:=Integer(Params[0])+4;
    Result:=d;
  end else
  if sMethodName = 'READH' then begin
    pct:=TfsScript(Integer(Params[1])).Variables['pck'];
    if Integer(Params[0])<Length(pct) then Move(pct[Integer(Params[0])],h,2);
    Params[0]:=Integer(Params[0])+2;
    Result:=h;
  end else
  if sMethodName = 'READF' then begin
    pct:=TfsScript(Integer(Params[1])).Variables['pck'];
    if Integer(Params[0])<Length(pct)-6 then Move(pct[Integer(Params[0])],f,8);
    Params[0]:=Integer(Params[0])+8;
    Result:=f;
  end else
  if sMethodName = 'READS' then begin
    pct:=TfsScript(Integer(Params[1])).Variables['pck'];
    d:=PosEx(#0#0,pct,Integer(Params[0]))-Integer(Params[0]);
    if (d mod 2)=1 then Inc(d);
    SetLength(temp,d div 2);
    if d>=2 then Move(pct[Integer(Params[0])],temp[1],d) else d:=0;
    Params[0]:=Integer(Params[0])+d+2;
    tmp:=temp;
    Result:=tmp;//WideStringToString(temp,1251);
  end else
  if sMethodName = 'WRITEC' then begin
    buf:=TfsScript(Integer(Params[2])).Variables['buf'];
    b:=Params[0];
    if Integer(Params[1])=0 then buf:=buf+Char(b)
      else buf[Integer(Params[1])]:=Char(b);
    TfsScript(Integer(Params[2])).Variables['buf']:=buf;
  end else
  if sMethodName = 'WRITED' then begin
    buf:=TfsScript(Integer(Params[2])).Variables['buf'];
    SetLength(tmp,4);
    d:=Params[0];
    if Integer(Params[1])=0 then begin
      Move(d,tmp[1],4);
      buf:=buf+tmp;
    end else begin
      Move(d,buf[Integer(Params[1])],4);
    end;
    TfsScript(Integer(Params[2])).Variables['buf']:=buf;
  end else
  if sMethodName = 'WRITEH' then begin
    buf:=TfsScript(Integer(Params[2])).Variables['buf'];
    SetLength(tmp,2);
    h:=Params[0];
    if Integer(Params[1])=0 then begin
      Move(h,tmp[1],2);
      buf:=buf+tmp;
    end else begin
      Move(h,buf[Integer(Params[1])],2);
    end;
    TfsScript(Integer(Params[2])).Variables['buf']:=buf;
  end else
  if sMethodName = 'WRITEF' then begin
    buf:=TfsScript(Integer(Params[2])).Variables['buf'];
    SetLength(tmp,8);
    f:=Params[0];
    if Integer(Params[1])=0 then begin
      Move(f,tmp[1],8);
      buf:=buf+tmp;
    end else begin
      Move(f,buf[Integer(Params[1])],8);
    end;
    TfsScript(Integer(Params[2])).Variables['buf']:=buf;
  end else
  if sMethodName = 'WRITES' then begin
    buf:=TfsScript(Integer(Params[1])).Variables['buf'];
    tmp:=Params[0];
    temp:=tmp;//StringToWideString(tmp,1251);
    tmp:=tmp+tmp;
    Move(temp[1],tmp[1],Length(tmp));
    {if Integer(Params[1])=0 then }
    buf:=buf+tmp+#0#0;
    { else begin
//      buf[Integer(Params[1])]:=Char(5);
    end;}
    TfsScript(Integer(Params[1])).Variables['buf']:=buf;
  end else
  if sMethodName = 'LOADLIBRARY' then begin
    Result := LoadLibrary(PAnsiChar(VarToStr(Params[0])));
  end else
  if sMethodName = 'HSTR' then Result:=HexToString(Params[0]) else
  //for support DLL
  if sMethodName = 'STRTOHEX' then Result:=StringToHex(Params[0],'') else
  if sMethodName = 'CALLPR' then begin
    @TestProc := nil;
    @TestProc := GetProcAddress(Cardinal(Params[0]),PAnsiChar(VarToStr(Params[1])));
    if @TestProc <> nil then begin
      Count := Params[2];
      setLength(popa,count);
      for i:=0 to Count-1 do
      popa[i]:=PChar(VarToStr(Params[3][i]));
      TestProc(popa);
    end;
    @TestProc:=nil;
  end else
  if sMethodName = 'CALLFNC' then begin
    @TestFunc := nil;
    @TestFunc := GetProcAddress(Cardinal(Params[0]),PAnsiChar(VarToStr(Params[1])));
    if @TestFunc <> nil then begin
      Count := Params[2];
      setLength(popa,count);
      for i:=0 to Count-1 do
      popa[i]:=PChar(VarToStr(Params[3][i]));
      Result:=StrPas(TestFunc(popa));
    end;
    @TestFunc:=nil;
  end else
  if sMethodName = 'TESTFUNC' then begin
    @tstFunc:= nil;
    @tstFunc := GetProcAddress(Cardinal(Params[0]),PAnsiChar(VarToStr(Params[1])));
    if @tstFunc <> nil then begin
      Count := Params[2];
      tstFunc(Count);
    end;
  end else
  if sMethodName = 'TESTFUNC1' then begin
    @tstFunc1:= nil;
    @tstFunc1 := GetProcAddress(Cardinal(Params[0]),PAnsiChar(VarToStr(Params[1])));
    if @tstFunc1 <> nil then begin
      Count1 := PAnsiChar(VarToStr(Params[2]));
      tstFunc1(Count1);
    end;
  end else
{/*by wanick*/}
  if sMethodName = 'CALLSF' then begin
    Res:= -1;
    SelectedScript := nil;
    if Params[0] <> '' then
      SelectedScript := fScript.FindScriptByName(Params[0]);
    if SelectedScript = nil then
      begin
        AddToLog ('Script: ������ � ������ '+Params[0]+'�� ������ !');
      end
    else
      begin //������ ������.
          if not SelectedScript.ListItem.Checked then
            //�� ��� ���� �� �������
            AddToLog ('������ � �������� �� ����������� ('+Params[0]+') �� �������!')
          else
            try//��� � �������
            Result := SelectedScript.fsScript.CallFunction(Params[1], Params[2]);
            except
            AddToLog ('��� ������ '+Params[0]+' ��������� ������ � ���������� ������! ('+inttostr(GetLastError)+')')
            end;

      end;
  end else 
  if sMethodName = 'SENDMSG'  then
  begin
    if Params[0] <> null then
      AddToLog('Script: '+Params[0]);
  end else
{/*by wanick*/}
  //for support DLL
  if sMethodName = 'CALLFUNCTION' then begin
    LibHAndle := nil;
    LibHandle := GetProcAddress(Cardinal(Params[0]),PAnsiChar(VarToStr(Params[1])));
    if LibHandle <> nil then begin
      Count := Params[2];
      SetLength(Par,Count);
      List := VarArrayRef(Params[3]);
      for i:= 0 to count -1 do
        Par[i]  := FindVarData(VarArrayRef(List)[i])^.VPointer;
      asm
        pusha;
        mov edx,[par]
        mov ecx, Count;
        cmp ecx,0
        jz @@m1;
        @@loop:
        dec ecx;
        mov eax,[edx + ecx*4];
        push eax;
        jnz @@loop;
        @@m1:
        call LibHandle;
        mov Res,eax;
        popa;
      end;
      List := 0;
      Result := Res;
    end;
  end else
  if sMethodName = 'FREELIBRARY' then
    Result := FreeLibrary(Params[0]) else
  if sMethodName = 'CONNECTNAMEBYID' then begin
    Result:=CONNECTNAMEBYID(integer(Params[0]))
  end else
  if sMethodName = 'CONNECTIDBYNAME' then begin
    Result := ConnectIdByName(string(Params[0]));
  end else
  if sMethodName = 'SETNAME' then begin
    buf:=TfsScript(Integer(Params[1])).Variables['buf'];
    ConId:=TfsScript(Integer(Params[1])).Variables['ConnectID'];
    SetConName(ConId, String(Params[0]));
  end else
  if sMethodName = 'NOCLOSESERVERAFTERCLIENTDISCONNECT' then begin
    buf:=TfsScript(Integer(Params[0])).Variables['buf'];
    ConId:=TfsScript(Integer(Params[0])).Variables['ConnectID'];
    setNoDisconnectOnDisconnect(ConId, true, false);
  end else
  if sMethodName = 'CLOSESERVERAFTERCLIENTDISCONNECT' then begin
    buf:=TfsScript(Integer(Params[0])).Variables['buf'];
    ConId:=TfsScript(Integer(Params[0])).Variables['ConnectID'];
    setNoDisconnectOnDisconnect(ConId, false, true);
  end else
  if sMethodName = 'NOCLOSECLIENTAFTERSERVERDISCONNECT' then begin
    buf:=TfsScript(Integer(Params[0])).Variables['buf'];
    ConId:=TfsScript(Integer(Params[0])).Variables['ConnectID'];
    setNoDisconnectOnDisconnect(ConId, true, true);
  end else
  if sMethodName = 'CLOSECLIENTAFTERSERVERDISCONNECT' then begin
    buf:=TfsScript(Integer(Params[0])).Variables['buf'];
    ConId:=TfsScript(Integer(Params[0])).Variables['ConnectID'];
    setNoDisconnectOnDisconnect(ConId, false, false);
  end else
  if sMethodName = 'NOCLOSEFRAMEAFTERDISCONNECT' then begin
    buf:=TfsScript(Integer(Params[0])).Variables['buf'];
    ConId:=TfsScript(Integer(Params[0])).Variables['ConnectID'];
    setNoFreeOnConnectionLost(ConId, true);
  end else
  if sMethodName = 'CLOSEFRAMEAFTERDISCONNECT' then begin
    buf:=TfsScript(Integer(Params[0])).Variables['buf'];
    ConId:=TfsScript(Integer(Params[0])).Variables['ConnectID'];
    setNoFreeOnConnectionLost(ConId, false);
  end ELSE
  if sMethodName = 'DISCONNECT' then begin
    buf:=TfsScript(Integer(Params[0])).Variables['buf'];
    ConId:=TfsScript(Integer(Params[0])).Variables['ConnectID'];
    DoDisconnect(ConId);
  end else
  if sMethodName = 'DELAY' then Sleep(Params[0]) else
  if sMethodName = 'SHOWFORM' then
    begin
      UserForm.Show;
      L2PacketHackMain.nUserFormShow.Enabled := true;
    end
    else
  if sMethodName = 'HIDEFORM' then
      begin
      UserForm.Hide;
      L2PacketHackMain.nUserFormShow.Enabled := false;
    end
end;

procedure TdmData.SendPacket(Packet: Tpacket; tid: integer; ToServer: Boolean);
var
  i : integer;
begin
// ����������.
//����� ����� ����� ���������� �� ���� � ��������� ������
  i := 0;
  while i < LSPConnections.Count do
  begin
    if TlspConnection(LSPConnections.Items[i]).SocketNum = tid then
      begin
        dmData.encryptAndSend(TlspConnection(LSPConnections.Items[i]), Packet, toserver);
        exit;
      end;
    inc(i);
  end;

  i := 0;
  while i < sockEngine.tunels.Count do
  begin
    if Ttunel(sockEngine.tunels.Items[i]).serversocket = tid then
      begin
        Ttunel(sockEngine.tunels.Items[i]).EncryptAndSend(Packet, toserver);
        exit;
      end;
    inc(i);
  end;
end;

procedure TdmData.SendPacketToName(Packet: Tpacket; cName: string; ToServer: Boolean);
var
i : integer;
begin
//����������.
//����� ����� ���������� � �������� ������ � ��������� ������
  i := ConnectIdByName(cName);
  if i > 0 then
    SendPacket(Packet, i, ToServer);
end;

function TdmData.CONNECTNAMEBYID(id: integer): string;
var
  i : integer;
begin
// ����������.
//��������� ����� �� ������ ����������
  Result :=  '';
  i := 0;
  while i < LSPConnections.Count do
  begin
    if TlspConnection(LSPConnections.Items[i]).SocketNum = id then
      begin
        Result := TlspConnection(LSPConnections.Items[i]).EncDec.CharName;
        exit;
      end;
    inc(i);
  end;

  i := 0;
  while i < sockEngine.tunels.Count do
  begin
    if Ttunel(sockEngine.tunels.Items[i]).serversocket = id then
      begin
        result := Ttunel(sockEngine.tunels.Items[i]).EncDec.CharName;
        exit;
      end;
    inc(i);
  end;
end;

function TdmData.ConnectIdByName(cname: string): integer;
var
  i : integer;
begin
// ����������.
//��������� ���� �� �����
  Result :=  0;
  i := 0;
  while i < LSPConnections.Count do
  begin
    if LowerCase(TlspConnection(LSPConnections.Items[i]).EncDec.CharName) = LowerCase(cname) then
      begin
        Result := TlspConnection(LSPConnections.Items[i]).SocketNum;
        exit;
      end;
    inc(i);
  end;

  i := 0;
  while i < sockEngine.tunels.Count do
  begin
    if LowerCase(Ttunel(sockEngine.tunels.Items[i]).EncDec.CharName) = LowerCase(cname) then
      begin
        result := Ttunel(sockEngine.tunels.Items[i]).serversocket;
        exit;
      end;
    inc(i);
  end;
end;

procedure TdmData.SetConName(Id: integer; Name: string);
var
  i : integer;
begin
// ����������.
//���������� ����� ����������
  i := 0;
  while i < LSPConnections.Count do
  begin
    if TlspConnection(LSPConnections.Items[i]).SocketNum = id then
      begin
        TlspConnection(LSPConnections.Items[i]).EncDec.CharName := name;
        exit;
      end;
    inc(i);
  end;

  i := 0;
  while i < sockEngine.tunels.Count do
  begin
    if Ttunel(sockEngine.tunels.Items[i]).serversocket = id then
      begin
        Ttunel(sockEngine.tunels.Items[i]).EncDec.CharName := name;
        exit;
      end;
    inc(i);
  end;
end;

procedure TdmData.setNoDisconnectOnDisconnect(id: integer; NoFree: boolean;IsServer:boolean);
var
  i : integer;
begin
// ����������.
//��������� nofree
  i := 0;
  while i < sockEngine.tunels.Count do
  begin
    if Ttunel(sockEngine.tunels.Items[i]).serversocket = id then
      begin
        if IsServer then
        Ttunel(sockEngine.tunels.Items[i]).noFreeOnServerDisconnect := NoFree
        else
        Ttunel(sockEngine.tunels.Items[i]).noFreeOnClientDisconnect := NoFree;
        exit;
      end;
    inc(i);
  end;
end;


procedure TdmData.DoDisconnect(id: integer);
var
i : integer;
begin
  i := 0;
  while i < LSPConnections.Count do
  begin
    if TlspConnection(LSPConnections.Items[i]).SocketNum = id then
      begin
        TlspConnection(LSPConnections.Items[i]).mustbedestroyed := true;
        exit;
      end;
    inc(i);
  end;

  i := 0;
  while i < sockEngine.tunels.Count do
  begin
    if Ttunel(sockEngine.tunels.Items[i]).serversocket = id then
      begin
        Ttunel(sockEngine.tunels.Items[i]).mustbedestroyed := true;
        exit;
      end;
    inc(i);
  end;
end;


function TdmData.Compile(var fsScript: TfsScript;
  var JvHLEditor: TJvHLEditor;var StatBat:TStatusBar): Boolean;
var
  ps,x,y: Integer;
begin
  RefreshPrecompile(fsScript);
  fsScript.Lines:=JvHLEditor.Lines;
  if not fsScript.Compile then begin
    ps:=Pos(':',fsScript.ErrorPos);
    x:=StrToInt(Copy(fsScript.ErrorPos,ps+1,length(fsScript.ErrorPos)-ps));
    y:=StrToInt(Copy(fsScript.ErrorPos,1,ps-1));
    if JvHLEditor.Visible then
    begin
      JvHLEditor.SetFocus;
      JvHLEditor.SetCaret(x-1,y-1);
      JvHLEditor.SelectWordOnCaret;
      JvHLEditor.SelBackColor:=clRed;
    end;
    StatBat.SimpleText:='������: '+fsScript.ErrorMsg + ', �������: '+fsScript.ErrorPos;
    Result:=False;
  end else begin
    StatBat.SimpleText:='������ ��������';
    Result:=True;
  end;
end;

procedure TdmData.destroyDeadLogWievs;
var
  i: integer;
begin
  if not Assigned(PacketLogWievs) then exit;
  i := 0;
  while i < PacketLogWievs.Count do
  begin
    if TpacketLogWiev(PacketLogWievs.Items[i]).MustBeDestroyed then
    begin
      TpacketLogWiev(PacketLogWievs.Items[i]).destroy;
      break;
    end
    else
    inc(i);
  end;
end;

procedure TdmData.setNoFreeOnConnectionLost(id: integer; NoFree:boolean);
var
  i : integer;
begin
// ����������.
//��������� nofree
  i := 0;
  while i < LSPConnections.Count do
  begin
    if TlspConnection(LSPConnections.Items[i]).SocketNum = id then
      begin
        TlspConnection(LSPConnections.Items[i]).noFreeAfterDisconnect := NoFree;
        exit;
      end;
    inc(i);
  end;

  i := 0;
  while i < sockEngine.tunels.Count do
  begin
    if Ttunel(sockEngine.tunels.Items[i]).serversocket = id then
      begin
        Ttunel(sockEngine.tunels.Items[i]).noFreeAfterDisconnect := NoFree;
        exit;
      end;
    inc(i);
  end;
end;


{ TpacketLogWiev }

constructor TpacketLogWiev.create;
begin
  PacketLogWievs.Add(self);
  mustbedestroyed := false;
end;

destructor TpacketLogWiev.destroy;
var
  i : integer;
begin
  i := 0;
  while i < PacketLogWievs.Count do
    begin
      if PacketLogWievs.Items[i] = self then
        begin
          PacketLogWievs.Delete(i);
          break;
        end;
        inc(i);
    end;
  if Assigned(visual) then
    begin
      Visual.deinit;
      Visual.Destroy;
    end;

  if Assigned(AssignedTabSheet) then
    AssignedTabSheet.Destroy;    
  inherited;
end;

procedure TpacketLogWiev.INIT;
begin
  sFileName := Filename;
  AssignedTabSheet := TTabSheet.Create(L2PacketHackMain.pcClientsConnection);
  Visual := TfVisual.Create(AssignedTabSheet);
  Visual.currenttunel := nil;
  Visual.currentLSP := nil;
  Visual.Parent := AssignedTabSheet;
  Visual.setNofreeBtns(GlobalNoFreeAfterDisconnect);
  AssignedTabSheet.PageControl := L2PacketHackMain.pcClientsConnection;
  AssignedTabSheet.Caption := '[log]#'+ExtractFileName(Filename);
  if not L2PacketHackMain.pcClientsConnection.Visible then L2PacketHackMain.pcClientsConnection.Visible  := true;
  Visual.CurrentTpacketLog := self;
  Visual.init;
  visual.Panel7.Width := 30;//��� � ��� ������ ���� ������..
  
end;

end.
