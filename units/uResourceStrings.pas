unit uResourceStrings;

interface

resourcestring
  RsScryptingInstructions =
  '������� ���� �� ������� � ������ �������� '#10#13+
  '��������� ��� ��� ��������������'#10#13#10#13+
  '������ �� ����� ���������� ��� ������� ���������� �� ��� ��� - '#10#13+
  '���� �� �� ����� ������� ������������� � ������� �������� � ������ ��������'#10#13;
  
  rsTunelCreated = '������ ($%d) ������';
  rsTunelRUN = '������ ($%d) ������� ��� ������ � ������ � %d';
  rsTunelDestroy = '������ ($%d) ���������';
  rsTunelConnecting = '������ ($%d), ��������� ����� � %d / ���������� ����� � %d, ���������� � %s:%d .....';  
  rsTunelConnected = '������ ($%d), ��������� ����� � %d / ���������� ����� � %d, ���������� ����������� � %s:%d';
  rsTunelTimeout = '������ ($%d), ������ ���������� �� ��������';


  rsInjectConnectIntercepted = '(Inject.dll) ���������� ������� �� %d.%d.%d.%d:%d';
  rsInjectConnectInterceptOff = '(Inject.dll) ������� �� %d.%d.%d.%d:%d ������� (�������� ��������)';
  rsInjectConnectInterceptedIgnoder = '(Inject.dll) ������� �� %d.%d.%d.%d:%d ��������������';

  rsTunelServerDisconnect = '������ ($%d) ���������� �� �������';
  rsTunelClientDisconnect = '������ ($%d) ���������� �� �������';


  rsSocketEngineNewConnection = 'ServerListen: ���������� ����� ����������.';
  rsTsocketEngineError = '������: %s';
  rsTsocketEngineSocketError = '�� ������: %d ������: %d: %s ';

  rsSavingPacketLog = '��������� ��� �������...';
  rsConnectionName = '��� ���������� ��� ������ ($%d): %s';

  rsClientPatched0 = '������ ��������� ����� ������ %S (%s)';
  rsClientPatched1 = '������� ��������� ����� ������ %S (%s)';
  rsClientPatched2 = '������������� ��������� ����� ������ %S (%s)';
  
  rsUnLoadDllSuccessfully = '���������� %s ������� ���������';
  rsLoadDllUnSuccessful = '���������� %s ����������� ��� ������������� ������ �����������';
  rsLoadDllSuccessfully = '������� ��������� %s';
  rsStartLocalServer = '�� %d ��������������� ��������� ������';
  rsFailedLocalServer = '�� ������� ���������������� ��������� ������ �� ���� %d'+ #13#10+ '�������� ���� ���� ����� ������ �����������';

  rsLSPConnectionDetected = '(LSP) ���������� ���������� (����� %d) IP/port %s:%d. %s';
  rsLSPConnectionWillbeIntercepted = '���������� ����� �����������';
  rsLSPConnectionWillbeIgnored = '���������� ����� ���������������';
  rsLSPDisconnectDetected = '(LSP) ���������� ������� (����� %d)';

  RsAppError = '%s - ������ ����������';
  RsExceptionClass = '�����: %s';
  RsExceptionMessage = '���������: %s';
  RsExceptionAddr = '�����: %p';
  RsStackList = 'Stack list, generated %s'; //� �� ��� � ��� ���������� �� �����...
  RsModulesList = 'List of loaded modules:';
  RsOSVersion = 'System   : %s %s, Version: %d.%d, Build: %x, "%s"';
  RsProcessor = 'Processor: %s, %s, %d MHz';
  RsMemory = 'Memory: %d; free %d';
  RsScreenRes = 'Display  : %dx%d pixels, %d bpp';
  RsActiveControl = 'Active Controls hierarchy:';
  RsThread = 'Thread: %s';
  RsMissingVersionInfo = '(no version info)';
  RsMainThreadCallStack = 'Call stack for main thread';
  RsThreadCallStack = 'Call stack for thread %s';

implementation

end.
