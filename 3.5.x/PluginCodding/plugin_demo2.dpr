library plugin_demo2;

{$define RELEASE} // ��� ������������� � ������� ���������, ��� ������ ����� ���������������

uses
  FastMM4 in '..\fastmm\FastMM4.pas',
  FastMM4Messages in '..\fastmm\FastMM4Messages.pas',
  windows,

  // ������ � ���������� �������� �����
  // ������������ � ������� � ���������
  usharedstructs in '..\units\usharedstructs.pas';





var
  min_ver_a: array[0..3] of Byte = ( 3,5,23,      141   );
  min_ver: LongWord absolute min_ver_a; // ����������� �������������� ������ ���������
  ps: TPluginStruct; // ��������� ������������ � ������

// ����������� ���������� �������.
// ������ ������� �������� �������,
// ������ ����� ��������� ������ ���������
function GetPluginInfo(const ver: LongWord): PChar; stdcall;
begin
  if ver<min_ver then
    Result:='���������������� Plugin � ��������� l2phx'+sLineBreak+
            '��� ������ 3.5.23.141+'+sLineBreak+
            '� ��� ������ ������ ���������! ������ �� ������ ��������� � ��� ��������!'
  else
    Result:='���������������� Plugin � ��������� l2phx'+sLineBreak+
            '��� ������ 3.5.23.141+'+sLineBreak+
            '���������� ����� ������� ����� �������� ���� �������/��������� � ��'+sLineBreak+
            '';
end;

// ����������� ���������� �������.
// �������� ��������� � �������� �� ��� ������� �������� ���������,
// ������� ����� ���������� �� �������.
// ���� ����� False �� ������ �����������.
function SetStruct(const struct: PPluginStruct): Boolean; stdcall;
begin
  ps := struct^;
  Result:=True;
end;


// ������������� ���������� �������. (����� ������������� � �������)
// ���������� ��� ������ ���������� ������� ����������� � RefreshPrecompile
function OnCallMethod(const ConnectId, ScriptId: integer;
                      const MethodName: String; // ��� ������� � ������� ��������
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


// ������������ ������������ ���������� �������
exports
  GetPluginInfo,
  SetStruct,
  OnCallMethod,
  OnRefreshPrecompile;

begin
end.
