unit FindReplaceUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls;

type
  TFindReplaceForm = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    LblFind: TLabel;
    EdtFind: TEdit;
    BtnFind: TButton;
    BtnFindCancel: TButton;
    Label2: TLabel;
    EdtFind1: TEdit;
    Button2: TButton;
    BtnReplaceAll: TButton;
    Button4: TButton;
    Button5: TButton;
    EdtReplace: TEdit;
    Label1: TLabel;
    procedure BtnFindCancelClick(Sender: TObject);
    procedure BtnFindClick(Sender: TObject);
    procedure BtnReplaceClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure EdtFind1Change(Sender: TObject);
    procedure EdtFindChange(Sender: TObject);
    procedure BtnReplaceAllClick(Sender: TObject);
  private
    { Private declarations }
    function Search: boolean;
    function Replace: boolean;
    function Replace2: boolean;
  public
    { Public declarations }
  end;

var
  FindReplaceForm : TFindReplaceForm;
// str - �������� ������
// str1 - ���������, ���������� ������
// str2 - ���������� ������
  str0, str, str1, str2 : string;
  x, y, xx, x0, repln : Integer;
  flush : boolean;

implementation

uses main;

{$R *.dfm}

function Find(const S, P: string): Integer;
{������� Find ���� ��������� P � ������ S � ���������� ������ ������� �������
��������� ��� 0, ���� ��������� �� �������. ���� � ����� ������ ���� �����,
��� � ����������� ������� ������ ����, ��������������, � ��������� ���������
�� ������ ��������.
}
var
  i, j: Integer;
begin
  Result:=0;
  if Length(P)>Length(S) then
    Exit;
  for i:=x0+1 to Length(S)-Length(P)+1 do //x0 ������ �������� ��� ������ � ������
    for j:=1 to Length(P) do
      if P[j]<>S[i+j-1] then
        Break
      else if j=Length(P) then
      begin
        Result:=i;
        Exit;
      end;
end;

procedure TFindReplaceForm.EdtFind1Change(Sender: TObject);
begin
  EdtFind.Text:=EdtFind1.Text;
  str1:=EdtFind1.Text;
  str:=L2PacketHackMain.JvHLEditor1.Lines[y];
end;

procedure TFindReplaceForm.EdtFindChange(Sender: TObject);
begin
  EdtFind1.Text:=EdtFind.Text;
  str1:=EdtFind.Text;
  str:=L2PacketHackMain.JvHLEditor1.Lines[y];
end;

procedure TFindReplaceForm.FormShow(Sender: TObject);
begin
  x:=0;
  y:=0;
  x0:=0;
  flush:=false;
  str1:=EdtFind.Text;
  str:=L2PacketHackMain.JvHLEditor1.Lines[y];
end;

procedure TFindReplaceForm.BtnFindCancelClick(Sender: TObject);
begin
  Close;
end;

function TFindReplaceForm.Search: boolean;
begin
  x:=Find(uppercase(str), uppercase(EdtFind.Text)); // ���� ���������
  if x>0 then begin
    L2PacketHackMain.JvHLEditor1.SetFocus;
    L2PacketHackMain.JvHLEditor1.SetCaret(x,y);
    L2PacketHackMain.JvHLEditor1.SelectRange(xx+x-1,y,length(edtFind.Text)+xx+x-1,y);
    L2PacketHackMain.JvHLEditor1.SelBackColor:=clBlue;
    L2PacketHackMain.StatusBar1.SimpleText:='����� � '+inttostr(y+1)+' ������; '+inttostr(x)+' �������; ����� '+inttostr(length(edtFind.Text));
    Result:=true;
  end else begin
    Result:=false;
  end;
end;

function TFindReplaceForm.Replace: boolean;
begin
  x:=Find(uppercase(str), uppercase(EdtFind.Text)); // ���� ���������
  if x>0 then begin
    Delete(str, x, length(EdtFind.Text)); // ������� �
    Insert(edtReplace.Text, str, x); // ��������� �����
    L2PacketHackMain.JvHLEditor1.Lines[y]:=str; // �������� ������
    L2PacketHackMain.JvHLEditor1.SetFocus;
    L2PacketHackMain.JvHLEditor1.SetCaret(x,y);
    L2PacketHackMain.JvHLEditor1.SelectRange(xx+x-1,y,length(edtReplace.Text)+xx+x-1,y);
    L2PacketHackMain.JvHLEditor1.SelBackColor:=clBlue;
    L2PacketHackMain.StatusBar1.SimpleText:='����� � '+inttostr(y+1)+' ������; '+inttostr(x)+' �������; ����� '+inttostr(length(edtFind.Text));
    x0:=x+1; // ����� �������� ��� ������
    Result:=true;
  end else begin
    Result:=false;
  end;
end;

procedure TFindReplaceForm.BtnFindClick(Sender: TObject);
var
  tmp_y: integer;
begin
  tmp_y:=y;
  x0:=x+1; // ����� �������� ��� ������
  if Search then exit
  else begin
    inc(tmp_y); // ��������� �� ��������� ������
    for y:=tmp_y to L2PacketHackMain.JvHLEditor1.Lines.Count-1 do begin
      x0:=0;
      str:=L2PacketHackMain.JvHLEditor1.Lines[y];
      if Search then exit;
    end;
    if MessageDlg('������ �� �����.',mtInformation ,[mbOk],0)=mrOk then
  end;
end;

procedure TFindReplaceForm.BtnReplaceClick(Sender: TObject);
var
  tmp_y: integer;
begin
  tmp_y:=y;    //����� ������
  x0:=x-1; // ����� �������� ��� ������
  if Replace then exit
  else begin
    inc(tmp_y); // ��������� �� ��������� ������
    for y:=tmp_y to L2PacketHackMain.JvHLEditor1.Lines.Count-1 do begin
      x0:=0;
      str:=L2PacketHackMain.JvHLEditor1.Lines[y];
      if Replace then exit;
    end;
  if MessageDlg('������ �� �����.', mtInformation, [mbOk],0)=mrOk then
  end;
end;

function TFindReplaceForm.Replace2: boolean;
begin
  x:=Find(uppercase(str), uppercase(EdtFind.Text)); // ���� ���������
  if x>0 then begin
    Delete(str, x, length(EdtFind.Text)); // ������� �
    Insert(edtReplace.Text, str, x); // ��������� �����
    L2PacketHackMain.JvHLEditor1.Lines[y]:=str; // �������� ������
    x0:=x+1; // ����� �������� ��� ������
    Result:=true;
  end else begin
    Result:=false;
  end;
end;

procedure TFindReplaceForm.BtnReplaceAllClick(Sender: TObject);
var
  tmp_y: integer;
begin
  tmp_y:=y;    //����� ������
  x0:=x+1; // ����� �������� ��� ������
  inc(tmp_y); // ��������� �� ��������� ������
  for y:=tmp_y to L2PacketHackMain.JvHLEditor1.Lines.Count-1 do begin
    x0:=0;
    str:=L2PacketHackMain.JvHLEditor1.Lines[y];
    Replace2;
  end;
  if MessageDlg('�� ��������.',mtInformation ,[mbOk],0)=mrOk then
end;

end.
