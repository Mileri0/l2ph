unit ReplaceUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TReplaceForm = class(TForm)
    BtnFind: TButton;
    BtnFindCancel: TButton;
    LblFind: TLabel;
    EdtFind: TEdit;
    Label1: TLabel;
    EdtReplace: TEdit;
    BtnReplace: TButton;
    procedure BtnFindCancelClick(Sender: TObject);
    procedure BtnFindClick(Sender: TObject);
    procedure BtnReplaceClick(Sender: TObject);
  private
    { Private declarations }
    function Replace(const Str, Str1, Str2: string): string;
    function Search: boolean;
  public
    { Public declarations }
  end;

var
  ReplaceForm : TReplaceForm;
  str, str1 : string;
  x, y, xx, repln : Integer;
  flush : boolean;

implementation

uses main;

{$R *.dfm}

procedure TReplaceForm.BtnFindCancelClick(Sender: TObject);
begin
  Close;
end;

function TReplaceForm.Search(): boolean;
begin
    x:=Pos(uppercase(EdtFind.Text), uppercase(str)); // ���� ���������
    if x>0 then begin
      L2PacketHackMain.JvHLEditor1.SetFocus;
      L2PacketHackMain.JvHLEditor1.SetCaret(x,y);
      L2PacketHackMain.JvHLEditor1.SelectRange(xx+x-1,y,length(edtFind.Text)+xx+x-1,y);
      L2PacketHackMain.JvHLEditor1.SelBackColor:=clBlue;
      L2PacketHackMain.StatusBar1.SimpleText:='����� � ������:'+inttostr(y+1)+' �������:'+inttostr(x)+' �����:'+inttostr(length(edtFind.Text));
      btnReplace.Enabled:=true; //����� ������ ��������
      Result:=true;
    end else begin
      btnReplace.Enabled:=false; //������ ������ ��������
      Result:=false;
    end;
end;

procedure TReplaceForm.BtnReplaceClick(Sender: TObject);
var
  tmp_y: integer;
begin
  str1:=copy(str,x+1,length(str)-x);
  Delete(str1, x, length(str)); // ������� ��
  Insert(edtReplace.Text, str1, x); // ��������� �����
  x:=Pos(uppercase(EdtReplace.Text), uppercase(str1)); // ���� ���������
  if x>0 then begin

  end;

//  tmp_y:=y;
//  xx:=x;
//  str:=copy(str,x+1,length(str)-x);
//  if Search then exit
//  else begin
//    inc(tmp_y); // ��������� �� ��������� ������
//    for y:=tmp_y to L2PacketHackMain.JvHLEditor1.Lines.Count-1 do begin
//      xx:=0;
//      str:=L2PacketHackMain.JvHLEditor1.Lines[y];
//      if Search then exit;
//    end;
//    if MessageDlg('������ �� �����.',mtInformation ,[mbOk],0)=mrOk then
//  end;
end;

procedure TReplaceForm.BtnFindClick(Sender: TObject);
begin
  x:=0;
  for y:=0 to L2PacketHackMain.JvHLEditor1.Lines.Count-1 do begin
    xx:=0;
    str:=L2PacketHackMain.JvHLEditor1.Lines[y];
    if Search then exit;
  end;
  if MessageDlg('������ �� �����.',mtInformation ,[mbOk],0)=mrOk then
end;

function TReplaceForm.Replace(const Str, Str1, Str2: string): string;
// str - �������� ������
// str1 - ���������, ���������� ������
// str2 - ���������� ������
//var
//  P, L: Integer;
//begin
//  Result:=str;
//  L:=Length(Str1);
//  flush:=false;
////  if Length(str)>=L then begin
////  repeat
//    //����� ���������� ������ � ������ ������, ���������� ��������
//    //���� ����������� ����� CallPr -> CallProc = CallPrococococococ... ������������!
//    P:=Pos(uppercase(Str1), uppercase(Result)); // ���� ���������
//    if P>0 then begin
//      inc(repln);
//      Delete(Result, P, L); // ������� ��
//      Insert(Str2, Result, P); // ��������� �����
//      flush:=true; //���� ��������� ������
//      P:=Pos(uppercase(Result), uppercase(str)); // ���� ���������
//      if P>0 then begin
//        str:=copy(str,x+1,length(str)-x);
//      end;
//
//    end;
////  until P=0;
////  end; // else  Result:=str2;
begin
//  x:=0;
//  for y:=0 to L2PacketHackMain.JvHLEditor1.Lines.Count-1 do begin
//    xx:=0;
//    str:=L2PacketHackMain.JvHLEditor1.Lines[y];
//    if Search then exit;
//  end;
//  if MessageDlg('������ �� �����.',mtInformation ,[mbOk],0)=mrOk then
end;

end.
