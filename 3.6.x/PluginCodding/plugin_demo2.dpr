library plugin_demo2;

{$define RELEASE} // ��� ������������� � ������� ���������, ��� ������ ����� ���������������

uses
  FastMM4 in '..\fastmm\FastMM4.pas',
  FastMM4Messages in '..\fastmm\FastMM4Messages.pas',
  windows,

  // ������ � ���������� �������� �����
  // ������������ � ������� � ���������
  usharedstructs in '..\units\usharedstructs.pas';





var                                {version} {revision}
  min_ver_a: array[0..3] of Byte = ( 3,5,1,      98   );
  min_ver: Integer absolute min_ver_a; // ����������� �������������� ������ ���������
  ps: TPluginStruct; // ��������� ������������ � ������

// ����������� ���������� �������.
// ������ ������� �������� �������,
// ������ ����� ��������� ������ ���������
function GetPluginInfo(const ver: Integer): PChar; stdcall;
begin
  if ver<min_ver then
    Result:='���������������� Plugin � ��������� l2phx'+sLineBreak+
            '��� ������ 3.5.1.98+'+sLineBreak+
            '� ��� ������ ������ ���������! ������ �� ������ ��������� � ��� ��������!'
  else
    Result:='���������������� Plugin � ��������� l2phx'+sLineBreak+
            '��� ������ 3.5.1.98+'+sLineBreak+
            '���������� ����� ������� ����� �������� ���� �������/��������� � ��'+sLineBreak+
            '';
end;

// ����������� ���������� �������.
// �������� ��������� � �������� �� ��� ������� �������� ���������,
// ������� ����� ���������� �� �������.
// ���� ����� False �� ������ �����������.
function SetStruct(const struct: PPluginStruct): Boolean; stdcall;
begin
  ps := TPluginStruct(struct^);
  Result:=True;
end;

// ������������� ���������� �������. (����� ������������� � �������)
// ���������� ��� ��������� ���������� (cnt) � �������� (withServer=False) 
// ��� �������� (withServer=True)
procedure OnConnect(const cnt: Cardinal; // ����� ����������
                    const withServer: Boolean); stdcall; // � ��������?
begin

end;

// ������������� ���������� �������. (����� ������������� � �������)
// ���������� ��� ������� ���������� (cnt) � �������� (withServer=False)
// ��� �������� (withServer=True)
procedure OnDisconnect(const cnt: Cardinal; // ����� ����������
                       const withServer: Boolean); stdcall; // � ��������?
begin

end;

// ������������� ���������� �������. (����� ������������� � �������)
// ���������� ��� �������� �������
procedure OnFree; stdcall;
begin

end;

// ������������� ���������� �������. (����� ������������� � �������)
// ���������� ��� �������� �������
procedure OnLoad; stdcall;
begin

end;

// ������������� ���������� �������. (����� ������������� � �������)
// ���������� ��� ������ ���������� ������� ����������� � RefreshPrecompile
function OnCallMethod(const MethodName: String; // ��� ������� � ������� ��������
                      var Params, // ��������� �������
                      FuncResult: Variant // ��������� �������
         ): Boolean; stdcall; // ���� ����� True �� ����������
                              // ��������� ������� ������������
begin
  Result:=False; // ������� ��������� ������� ���������
  if MethodName='PI' then begin
    Result:=True; // ��������� ���������� ��������� ������� � ���������
    FuncResult:=Pi;
  end;

  if MethodName='SHOW_MY_MESSAGE' then begin
    MessageBox(0,pchar(string(Params[0])),'',MB_OK);
    Result:=True; // ��������� ���������� ��������� ������� � ���������
    FuncResult:=0; //����� ��������� ? ��� ���������.
  end;
end;

// ������������� ���������� �������. (����� ������������� � �������)
// ���������� ����� ������������ �������, ��������� ��������� ���� ������� � �������� / ���������� ������
Procedure OnRefreshPrecompile; stdcall;
begin
  ps.UserFuncs.Add('function Pi:Extended');
  ps.UserFuncs.Add('procedure Show_my_message(msg:string)');
  //� ��� ������ ��������
  //ps.UserFuncs.Add('procedure Show_my_message(%s)');
  //%s ������� � ��� ��� ������� � ����� ���������� ����� ���������� ����������
  //��������� ������ TfsScript
  //%s ������ ���� ��������� ���� ������������ ����������
  //� ������� ���������� ��������� ������� � ��
  //
  //'procedure SetName(Name:string;%s)'
  //'procedure Disconnect(%s)'
  //'procedure WriteS(v:string;%s)'
  //
  //�������� �������� �� ";" ����� ����������, �� ���� ��� ������� ��� %s �� ������������ �������� �������
  //��� ��� ����:
  //����������� ����������� ���������� � �����������.
  //��� ��� ��������� � ��:
  {
  if sMethodName = 'DISCONNECT' then
  begin
    ConId:=TfsScript(Integer(Params[0])).Variables['ConnectID'];
    DoDisconnect(ConId);
  end

  ����

  if sMethodName = 'SETNAME' then
  begin
    buf:=TfsScript(Integer(Params[1])).Variables['buf'];
    ConId:=TfsScript(Integer(Params[1])).Variables['ConnectID'];
    SetConName(ConId, String(Params[0]));
  end  
  }
  //TfsScript(Integer(Params[0])) - ��������� TfsScript


end;


// ������������� ���������� �������. (����� ������������� � �������)
// ���������� ��� ������� ������, ���������:
// cnt - ����� ����������
// fromServer - ���� ����� �� ������� ����� True, ���� �� ������� �� False
// pck - ���������� ����� (� ���� �������)
procedure OnPacket(const cnt: Cardinal; const fromServer: Boolean; var pck: TPacket); stdcall;
begin
  if pck.size<3 then exit; // �� ������ ���� ���������� ������� �������� �����

end;

// ������������ ������������ ���������� �������
exports
  GetPluginInfo,
  SetStruct,
  OnPacket,
  OnConnect,
  OnDisconnect,
  OnLoad,
  OnFree,
  OnCallMethod,
  OnRefreshPrecompile;

begin
end.
