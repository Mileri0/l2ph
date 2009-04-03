library plugin_demo3;

{$define RELEASE} // ��� ������������� � ������� ���������, ��� ������ ����� ���������������

uses
  windows,
  FastMM4 in '..\fastmm\FastMM4.pas',
  FastMM4Messages in '..\fastmm\FastMM4Messages.pas',
  usharedstructs in '..\units\usharedstructs.pas',
  plugin_demo3_form in 'plugin_demo3_form.pas' {MyForm};

var                                {version} {revision}
  min_ver_a: array[0..3] of Byte = ( 3,5,1,      84   );
  min_ver: Integer absolute min_ver_a; // ����������� �������������� ������ ���������
  ps: TPluginStruct; // ��������� ������������ � ������

// ����������� ���������� �������.
// ������ ������� �������� �������,
// ������ ����� ��������� ������ ���������
function GetPluginInfo(const ver: Integer): PChar; stdcall;
begin
  if ver<min_ver then
    Result:='���������������� Plugin � ��������� l2phx'+sLineBreak+
            '��� ������ 3.5.1+'+sLineBreak+
            '� ��� ������ ������ ���������! ������ �� ������ ��������� � ��� ��������!'
  else
    Result:='���������������� Plugin � ��������� l2phx'+sLineBreak+
            '��� ������ 3.5.1+'+sLineBreak+
            '��� ����� ������������ ���������������� ����� ?';
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
  MyForm.Destroy;
end;

// ������������� ���������� �������. (����� ������������� � �������)
// ���������� ��� �������� �������
procedure OnLoad; stdcall;
begin
  MyForm := TMyForm.Create(nil);
  SetParent(MyForm.Handle,ps.userFormHandle);
  ps.ShowUserForm(false);
  MyForm.Show;
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
  OnFree;   
begin
end.
