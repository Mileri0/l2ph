unit uData;

interface

uses
  uResourceStrings,
  uGlobalFuncs,
  ecSyntMemo,
  SysUtils,
  Classes,
  Forms,
  Dialogs,
  Graphics, 
  LSPControl,
  LSPStructures,
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
  ecPopupCtrl,
  SyncObjs,
  siComp;

type
  TlspConnection = class (tobject)
    Visual: TfVisual;
    AssignedTabSheet : TTabSheet;
    EncDec : TEncDec;
    SocketNum : integer;
    tempfilename:string;

  private
  public
    active : boolean;
    RawLog : TFileStream;
    isRawAllowed:boolean;
    tempbufferRecv, tempbufferSend : array [0..$ffff] of byte;
    TempBufferRecvLen, TempBufferSendLen :cardinal;
    mustbedestroyed: boolean;
    DisconnectAfterDestroy : boolean;
    noFreeAfterDisconnect: boolean;
    procedure encryptAndSend(Packet: Tpacket; ToServer: Boolean);    
    procedure NewAction(action : byte; Caller: TObject);
    procedure NewPacket(var Packet:Tpacket;FromServer: boolean; Caller: TObject);
    constructor create(SocketN:integer);
    Procedure   INIT;
    procedure disconnect;
    destructor  Destroy; override;
    Procedure AddToRawLog(dirrection : byte; data:tbuffer; size:word);
  end;

  TpacketLogWiev = class (TObject)
    Visual: TfVisual;
    AssignedTabSheet : TTabSheet;
    MustBeDestroyed : boolean;
    sFileName:string;
  public
    constructor create;
    Procedure   INIT(Filename:string);
    destructor  Destroy; override;
  end;
  
  TdmData = class(TDataModule)
    timerSearchProcesses: TTimer;
    lang: TsiLang;
    LSPControl: TLSPModuleControl;
    procedure LSPControlLspModuleState(state: Byte);
    procedure timerSearchProcessesTimer(Sender: TObject);
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
    procedure LSPControlConnect(var Struct: TConnectStruct;
      var hook: Boolean);
    procedure LSPControlDisconnect(var Struct: TDisconnectStruct);
    procedure LSPControlRecv(const inStruct: TSendRecvStruct;
      var OutStruct: TSendRecvStruct);
    procedure LSPControlSend(const inStruct: TSendRecvStruct;
      var OutStruct: TSendRecvStruct);
  private
    CriticalSection  : TCriticalSection;
    { Private declarations }
  public
    function FindLspConnectionBySockNum(SockNum:integer):TlspConnection;
    procedure destroyDeadLSPConnections;
    procedure destroyDeadLogWievs;

    procedure ScryptProcessPacket(var newpacket: tpacket; FromServer: boolean; Id: integer);

    procedure SendPacket(Packet: Tpacket; tid: integer; ToServer: Boolean);
    procedure SendPacketToName(Packet: Tpacket; cName: string; ToServer: Boolean);
    function ConnectNameById(id:integer):string;
    function ConnectIdByName(cname:string):integer;
    procedure SetConName(Id:integer; Name:string);

              //����������� �������� :)
    Procedure setNoDisconnectOnDisconnect(id:integer; NoFree:boolean;IsServer:boolean);
    Procedure setNoFreeOnConnectionLost(id:integer; NoFree:boolean);
    procedure DoDisconnect(id:integer);
//    function Compile(var fsScript: TfsScript; Editor: TSyntaxMemo; var StatBat:TStatusBar): Boolean;
//    procedure RefreshPrecompile(var fsScript: TfsScript);
  end;

var
  dmData: TdmData;
  Processes :TStringList;
  LSPConnections, PacketLogWievs:Tlist;
  sockEngine : TSocketEngine;


implementation
uses uPluginData, uPlugins, umain, uSettingsDialog, uProcesses, advApiHook,
  uScriptControl, uScriptProject;

{$R *.dfm}

{ TdmData }



procedure TdmData.LSPControlLspModuleState(state: Byte);
begin
if fSettings.InterfaceEnabled then
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
  ListSearch := LowerCase(sClientsList); // � ������ �������
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
    if (fProcesses.FoundProcesses.Items.IndexOf(tmp.ValueFromIndex[i]+' ('+tmp.Names[i]+')')=-1) then
    begin
      fProcesses.FoundProcesses.Items.Clear;
      fProcesses.FoundClients.Items.Clear;
      for k := 0 to tmp.Count - 1 do
      begin
        // ��������� � ���� ��������� ���������
        fProcesses.FoundProcesses.Items.Add(tmp.ValueFromIndex[k]+' ('+tmp.Names[k]+')');
        //���������� ��������� ��������� �� ������� ����������� ��������
        if (AnsiPos(tmp.ValueFromIndex[k]+';', ListSearch) > 0) and (tmp.ValueFromIndex[k] <> '')  then
        begin
          if fSettings.ChkIntercept.Checked and (Processes.Values[tmp.Names[k]]='') then
          begin
            Processes.Values[tmp.Names[k]] := 'error';
            cc := OpenProcess(PROCESS_ALL_ACCESS,False,StrToInt(tmp.Names[k]));
            case fSettings.HookMethod.ItemIndex of
              0:
              begin
                if InjectDll(cc, PChar(fSettings.isInject.Text)) then
                begin
                  Processes.Values[tmp.Names[k]]:='ok';
                  AddToLog (format(rsClientPatched0, [tmp.ValueFromIndex[k], tmp.Names[k]]));
                end;
              end;
              1:
              begin
                if InjectDllEx(cc, pInjectDll) then
                begin
                  Processes.Values[tmp.Names[k]]:='ok';
                  AddToLog (format(rsClientPatched1, [tmp.ValueFromIndex[k], tmp.Names[k]]));
                end;
              end;
              2:
              begin
                if InjectDllAlt(cc, PChar(fSettings.isInject.Text)) then
                begin
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

procedure TlspConnection.AddToRawLog(dirrection: byte; data:tbuffer;
  size: word);
var
  dtime: Double;
begin
  if not isRawAllowed then exit;
  RawLog.WriteBuffer(dirrection,1);
  dtime := now;
  RawLog.WriteBuffer(dtime,8);
  RawLog.WriteBuffer(size,2);
  RawLog.WriteBuffer(data[0],size);
end;

constructor TlspConnection.create;
begin
  LSPConnections.Add(self);
  tempfilename := AppPath+'settings\RAW.'+IntToStr(round(random(1000000)*10000))+'.temp';
  RawLog := TFileStream.Create(tempfilename, fmOpenWrite or fmCreate);
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
  if DisconnectAfterDestroy then
    if SocketNum <> 0 then
      begin
        dmData.LSPControl.CloseSocket(SocketNum);
      end;

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


  if Assigned(visual) then
    begin
      Visual.deinit;
      Visual.Destroy;
    end;
  EncDec.destroy;
  if Assigned(AssignedTabSheet) then
    AssignedTabSheet.Destroy;
  RawLog.Destroy;
  DeleteFile(pchar(tempfilename));
  inherited;
end;

procedure TlspConnection.disconnect;
begin
dmData.LSPControl.CloseSocket(SocketNum);
end;

procedure TlspConnection.encryptAndSend(Packet: Tpacket; ToServer: Boolean);
var
  Dirrection : byte;
  struct : TSendRecvStruct;
begin
{ TODO : �� ���������. ����������� ������ ��� �������� }
if assigned(Visual) then
  begin
    Visual.AddPacketToAcum(Packet, not ToServer, EncDec);
    Visual.processpacketfromacum;
  end;

  //��������
  if ToServer then
    Dirrection := PCK_GS_ToServer
  else
    Dirrection := PCK_GS_ToClient;

  EncDec.EncodePacket(packet, Dirrection);

  //��������� ���������
  struct.SockNum := SocketNum;
  FillChar(struct.CurrentBuff[0], $ffff, #0);

  Move(Packet.PacketAsByteArray[0], struct.CurrentBuff[0], Packet.Size);
  struct.CurrentSize := Packet.Size;


  if ToServer then
    dmData.LSPControl.SendToServer(struct)
  else
    dmData.LSPControl.SendToClient(struct);

end;


procedure TlspConnection.INIT;
begin
  EncDec.onNewAction := NewAction;
  EncDec.onNewPacket := NewPacket;
  EncDec.init;
  AssignedTabSheet := TTabSheet.Create(fMain.pcClientsConnection);
  AssignedTabSheet.PageControl := fMain.pcClientsConnection;
  fMain.pcClientsConnection.ActivePageIndex := AssignedTabSheet.PageIndex;
  AssignedTabSheet.Show;

  Visual := TfVisual.Create(AssignedTabSheet);
  Visual.currenttunel := nil;
  Visual.CurrentTpacketLog := nil;
  Visual.Parent := AssignedTabSheet;
  Visual.setNofreeBtns(GlobalNoFreeAfterDisconnect);
  noFreeAfterDisconnect := GlobalNoFreeAfterDisconnect;
  AssignedTabSheet.PageControl := fMain.pcClientsConnection;
  AssignedTabSheet.Caption := '[lsp]#'+inttostr(SocketNum);
  if not fMain.pcClientsConnection.Visible then fMain.pcClientsConnection.Visible  := true;
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

end;

procedure TlspConnection.NewPacket(var Packet:Tpacket;FromServer: boolean; Caller: TObject);
begin
  { TODO : �������� �������� � �������� }
  dmdata.ScryptProcessPacket(packet, FromServer, TencDec(Caller).Ident); //�������� �������� � ��������
  if Packet.Size > 2 then //������� ���� ������� ����� ��������
  if assigned(visual) then
  begin
    Visual.AddPacketToAcum(Packet, FromServer, Caller);
    visual.processpacketfromacum;
  end;
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


procedure TdmData.ScryptProcessPacket(var newpacket: tpacket; FromServer: boolean; Id: integer);
//���� �������� ����� �������

var
  temp:string;
  i:integer;
  Project : TScriptProject;

begin

  //�� �������� ��� ������� ���� �� �����.
  for i := 0 to Plugins.Count - 1 do
    with TPlugin(Plugins.Items[i]) do
      if Loaded and Assigned(OnPacket) then
      begin
        OnPacket(id, FromServer, dmData.ConnectNameById(id), newpacket);
        //���� ������ ������� ������ ������
        if newpacket.Size < 3 then exit; //������ ��� ��� ����, �� ���� ������ ����� �������� �� �����. ������� �����.
      end;


  //�������
  setlength(temp,newpacket.Size - 2);
  Move(newpacket.data[0], temp[1], newpacket.size - 2);
  for i:=0 to fScriptControl.ProjectsList.Count-1 do
  begin
  
    Project := TScriptProject(fScriptControl.ProjectsList.Items[i]);
    if assigned(Project) then
      if Project.CanUse then
      begin
        //�� ������� �������� ���� ���������� ��������
        Project.sd.Pck := temp;
        Project.sd.Buf := '';
        Project.sd.ConnectID := id;
        Project.sd.ConnectName := dmdata.ConnectNameById(id);
        Project.sd.FromServer := FromServer;
        Project.sd.FromClient := not FromServer;
        try
          Project.OnPacket;
          temp := Project.sd.Pck;
          if temp = '' then break;
          
        except
        end;
      end;
  end;
  
  if length(temp) > 0 then
  begin
    newpacket.Size := length(temp) + 2;
    Move(temp[1], newpacket.data[0], newpacket.Size - 2);
  end
  else
  begin
    FillChar(newpacket.PacketAsCharArray[0], $ffff, #0)
  end;


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
    if (TlspConnection(LSPConnections.Items[i]).SocketNum = tid) then
      begin
        TlspConnection(LSPConnections.Items[i]).Visual.AddPacketToAcum(Packet, not ToServer, TlspConnection(LSPConnections.Items[i]).EncDec);
        TlspConnection(LSPConnections.Items[i]).Visual.processpacketfromacum;
        TlspConnection(LSPConnections.Items[i]).encryptAndSend(Packet, toserver);
        exit;
      end;
    inc(i);
  end;

  i := 0;
  while i < sockEngine.tunels.Count do
  begin
    if (Ttunel(sockEngine.tunels.Items[i]).serversocket = tid) then
      begin
        Ttunel(sockEngine.tunels.Items[i]).Visual.AddPacketToAcum(Packet, not ToServer, Ttunel(sockEngine.tunels.Items[i]).EncDec);
        Ttunel(sockEngine.tunels.Items[i]).Visual.processpacketfromacum;
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
    if (LowerCase(TlspConnection(LSPConnections.Items[i]).EncDec.CharName) = LowerCase(cname)) and
        (TlspConnection(LSPConnections.Items[i]).active) then
      begin
        Result := TlspConnection(LSPConnections.Items[i]).SocketNum;
        exit;
      end;
    inc(i);
  end;

  i := 0;
  while i < sockEngine.tunels.Count do
  begin
    if (LowerCase(Ttunel(sockEngine.tunels.Items[i]).EncDec.CharName) = LowerCase(cname)) and
     (Ttunel(sockEngine.tunels.Items[i]).active) then
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
  AssignedTabSheet := TTabSheet.Create(fMain.pcClientsConnection);
  AssignedTabSheet.PageControl := fMain.pcClientsConnection;
  fMain.pcClientsConnection.ActivePageIndex := AssignedTabSheet.PageIndex;
  AssignedTabSheet.Show;
  Visual := TfVisual.Create(AssignedTabSheet);
  Visual.currenttunel := nil;
  Visual.currentLSP := nil;
  Visual.Parent := AssignedTabSheet;
  Visual.setNofreeBtns(GlobalNoFreeAfterDisconnect);
  AssignedTabSheet.Caption := '[log]#'+ExtractFileName(Filename);
  if not fMain.pcClientsConnection.Visible then fMain.pcClientsConnection.Visible  := true;
  Visual.CurrentTpacketLog := self;
  Visual.init;
  visual.Panel7.Width := 30;//��� � ��� ������ ���� ������..

  
end;

procedure TdmData.LSPControlConnect(var Struct: TConnectStruct;
  var hook: Boolean);
var
  str : string;
  i : integer;
  newlspconnection : TlspConnection;
begin

  hook := (Pos(IntToStr(Struct.port)+';',sIgnorePorts+';')=0);
  if hook then
    str := rsLSPConnectionWillbeIntercepted
  else
    str := rsLSPConnectionWillbeIgnored;
  if hook then
    begin
      newlspconnection := TlspConnection.create(Struct.SockNum);
      newlspconnection.INIT;
      Application.ProcessMessages;
      //���������� �������
      for i:=0 to Plugins.Count - 1 do with TPlugin(Plugins.Items[i]) do
      if Loaded  then
      begin
        if Assigned(OnConnect) then OnConnect(Struct.SockNum, true);
        if Assigned(OnConnect) then OnConnect(Struct.SockNum, false);
      end;
    end;
  AddToLog(Format(rsLSPConnectionDetected, [Struct.SockNum, Struct.ip, Struct.port, str]));
end;
procedure TdmData.LSPControlDisconnect(var Struct: TDisconnectStruct);
var
  connection : TlspConnection;
  i : integer;

begin

  //���������� �������
  for i:=0 to Plugins.Count - 1 do with TPlugin(Plugins.Items[i]) do
  if Loaded  then
  begin
    if Assigned(OnDisconnect) then OnDisconnect(Struct.SockNum, true);
    if Assigned(OnDisconnect) then OnDisconnect(Struct.SockNum, false);
  end;


  connection := FindLspConnectionBySockNum(Struct.SockNum);
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
  AddToLog(Format(rsLSPDisconnectDetected, [Struct.SockNum]));
end;



procedure TdmData.LSPControlRecv(const inStruct: TSendRecvStruct;
  var OutStruct: TSendRecvStruct);
var
  LspConnection : TlspConnection;
  PcktLen : Word;
  tmppack:tpacket;
begin
  CriticalSection.Enter;
  LspConnection := FindLspConnectionBySockNum(inStruct.SockNum);
  OutStruct.SockNum := inStruct.SockNum;
  
  if LspConnection = nil then
    begin
      OutStruct := inStruct;
      exit;
    end;
  LspConnection.AddToRawLog(PCK_GS_ToClient, inStruct.CurrentBuff, inStruct.CurrentSize);
  { TODO : ��������� }
  if LspConnection.EncDec.Settings.isNoDecrypt then
    begin
      OutStruct := inStruct;
      exit;
    end;
  

//  ResultLen := 0;
//  FillChar(ResultBuff,$ffff,#0);
  //���������� ��� ����������� ������ �� ��������� ������ (������ �������������� ������)
  Move(inStruct.CurrentBuff[0], LspConnection.tempbufferRecv[LspConnection.TempBufferRecvLen], inStruct.CurrentSize);
  inc(LspConnection.TempBufferRecvLen, inStruct.CurrentSize);

  //�������� ������ ������ ����������� � ��������� ������
  Move(LspConnection.TempBufferRecv[0], PcktLen, 2);
  if PcktLen=29754 then PcktLen:=267;
  //���� � ��� ������� ������ � ������� ����� �������� ����� ��������� - ������������ �����
  while (LspConnection.TempBufferRecvLen >= PcktLen) and (PcktLen >= 2) and (LspConnection.TempBufferRecvLen >= 2) do
  begin
    //��������� ������ � ���������� ������� � ��������� ������ �� ��������� 
    Move(LspConnection.TempBufferRecv[0], tmppack.PacketAsCharArray[0], PcktLen);
    //�������� ������ � ��������� ������� ������ ��������� ������
    move(LspConnection.TempBufferRecv[PcktLen], LspConnection.TempBufferRecv[0], LspConnection.TempBufferRecvLen);
    dec(LspConnection.TempBufferRecvLen, PcktLen);
    if PcktLen=29754 then PcktLen:=267;
    //������������ �����
    LspConnection.EncDec.DecodePacket(tmppack, PCK_GS_ToClient);
    if tmppack.Size > 2 then
    begin
      LspConnection.EncDec.EncodePacket(tmppack, PCK_GS_ToClient);
      //���������� ����������� �� ��������� �������������� ������
      Move(tmppack.PacketAsCharArray[0],  outStruct.CurrentBuff[outStruct.CurrentSize], tmppack.Size);
      inc(outStruct.CurrentSize, tmppack.Size);
      outStruct.exists := true;
    end;

    if LspConnection.TempBufferRecvLen > 2 then
      //�������� ������ ������ ����������� � ��������� ������
      Move(LspConnection.TempBufferRecv[0], PcktLen, 2)
    else
      PcktLen := 0;
  end;

  //� ����� � ��� ���������� �������������� ������
  CriticalSection.Leave;
end;

procedure TdmData.LSPControlSend(const inStruct: TSendRecvStruct;
  var OutStruct: TSendRecvStruct);
var
  LspConnection : TlspConnection;
  PcktLen : Word;
  tmppack:tpacket;
begin
  CriticalSection.Enter;
  LspConnection := FindLspConnectionBySockNum(inStruct.SockNum);
  OutStruct.SockNum := inStruct.SockNum;
  if LspConnection = nil then
    begin
      OutStruct := inStruct;    
      exit;
    end;
    
  LspConnection.AddToRawLog(PCK_GS_ToServer, inStruct.CurrentBuff, inStruct.CurrentSize);
  { TODO : ��������� }
  if LspConnection.EncDec.Settings.isNoDecrypt then
    begin
      OutStruct := inStruct;
      exit;
    end;

  //���������� ��� ����������� ������ �� ��������� ������ (������ �������������� ������)
  Move(inStruct.CurrentBuff[0],LspConnection.tempbufferSend[LspConnection.TempBufferSendLen], inStruct.CurrentSize);
  inc(LspConnection.TempBufferSendLen, inStruct.CurrentSize);

  //�������� ������ ������ ����������� � ��������� ������
  Move(LspConnection.TempBufferSend[0], PcktLen, 2);

  //���� � ��� ������� ������ � ������� ����� �������� ����� ��������� - ������������  ���������
  while (LspConnection.TempBufferSendLen >= PcktLen) and (PcktLen >= 2) and (LspConnection.TempBufferSendLen >= 2) do
  begin
    //��������� ������ � ���������� ������� � ��������� ������ �� ��������� 
    Move(LspConnection.TempBufferSend[0], tmppack.PacketAsCharArray[0], PcktLen);

    //�������� � ��������� ������� ������ ��������� ������
    move(LspConnection.TempBufferSend[PcktLen], LspConnection.TempBufferSend[0], LspConnection.TempBufferSendLen);
    dec(LspConnection.TempBufferSendLen, PcktLen);

    //������������ �����
    LspConnection.EncDec.DecodePacket(tmppack, PCK_GS_ToServer);
    if tmppack.Size > 2 then
    begin
      LspConnection.EncDec.EncodePacket(tmppack, PCK_GS_ToServer);
      //���������� ����������� �� ��������� �������������� ������

      Move(tmppack.PacketAsCharArray[0], OutStruct.CurrentBuff[OutStruct.CurrentSize], tmppack.Size);
      //����������� ������� ���������� ��������������� �������
      inc(OutStruct.CurrentSize, tmppack.Size);
      OutStruct.exists := true;
    end;
    
    if LspConnection.TempBufferSendLen > 2 then
    //�������� ������ ������ ����������� � ��������� ������
    Move(LspConnection.TempBufferSend[0], PcktLen, 2)
    else
      PcktLen := 0;
  end;

  CriticalSection.Leave;
end;


end.
