library plugin_demo2;

{$define RELEASE} // ��� ������������� � ������� ���������, ��� ������ ����� ���������������

uses
  FastMM4,
  Coding in 'Coding.pas'; // ������ � ���������� �������� �����
                          // ������������ � ������� � ���������

var                                {version} {revision}
  min_ver_a: array[0..3] of Byte = ( 3,4,1,      46   );
  min_ver: Integer absolute min_ver_a; // ����������� �������������� ������ ���������
  ps: TPluginStruct; // ��������� ������������ � ������

// ����������� ���������� �������.
// ������ ������� �������� �������,
// ������ ����� ��������� ������ ���������
function GetPluginInfo(const ver: Integer): PChar; stdcall;
begin
  if ver<min_ver then
    Result:='���������������� Plugin � ��������� l2phx'+sLineBreak+
            '��� ������ 3.4.0+'+sLineBreak+
            '� ��� ������ ������ ���������! ������ �� ������ ��������� � ��� ��������!'
  else
    Result:='���������������� Plugin � ��������� l2phx'+sLineBreak+
            '��� ������ 3.4.0+';
end;

// ����������� ���������� �������.
// �������� ��������� � �������� �� ��� ������� �������� ���������,
// ������� ����� ���������� �� �������.
// ���� ����� False �� ������ �����������.
function SetStruct(const struct: TPluginStruct): Boolean; stdcall;
begin
  ps:=struct;
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
end;

// ������������� ���������� �������. (����� ������������� � �������)
// ���������� ����� ����������� ��������
function OnRefreshPrecompile(var funcs: TStringArray): Integer; stdcall;
begin
  SetLength(funcs,1); // ��������� ���������� ����������� � ������ �������
  funcs[0]:='function Pi:Extended'; // ���� �� ����������� �������
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
