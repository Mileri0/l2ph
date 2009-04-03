unit LSPStructures;
interface
uses windows, JwaWinsock2;

const
  //� ��� ��� ����������... -)
  Apendix = '{27-06-22-78-28-31-94-8-30-50}';
  Mutexname = 'm' + Apendix;

  //������
  Action_client_connect = 1;
  Action_client_recv = 2;
  Action_client_send = 3;
  Action_client_disconnect = 4;
  Action_sendtoserver = 5;
  Action_closesocket = 7;

  //�������
  WM_action = $04F0;               

type

  //������.
  Tbuffer = array [0..$FFFF] of Byte;

  //�������� ����� ���������
  TShareMapMain = record
    ReciverHandle : Thandle;  //���� - ����� ������ ���������
    ProcessesForHook : string[100];  //���� - �� �������� � ������� ����� ������������� �������.
  end;
  PShareMapMain = ^TShareMapMain;

  //����� ��������� ��������
  TShareMapClient = record
    ReciverHandle : Thandle; //���� ����� ����� �������� ���������� �����������
    ip : string[15];  //���� ���������� ����� (������ ����. ���������� ���.)
    port : Cardinal;  //�� ����� ����
    application:string[255]; //��� �� ����������
    pid: Cardinal; //pid ��������
    Buff: Tbuffer;    //������ ��� ������ ������� � �������� �����������
    buffersize : cardinal; //������ ����� ������
    toclientbuffer: //��������� �����. ������������ ��� sendtoclient
    record
      Buff: Tbuffer; // ���������� �������
      buffsize: byte;
    end;
    ignorenextsend:boolean; //����, ������������ � WSPSend � ���
    hookithandle : thandle; //����� �������� ������������� � ��� ��� ������ ���������� ������� �������������.
  end;
  
  PShareMapClient = ^TShareMapClient;

  TshareClient =
    record
      SocketNum : cardinal;  //�����
      MapData  : PShareMapClient;  //��������� �� ���������
      MapHandle: THandle;  //����� ���������
    end;

  TshareMain =
    record
      MapData : PShareMapMain; //���������
      MapHandle : THandle; //������. -)
    end;
    
implementation

end.
