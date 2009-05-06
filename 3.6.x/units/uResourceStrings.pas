unit uResourceStrings;

interface

var

	rsTunelCreated: string = ''; (* ������ ($%d) ������ *)
	rsTunelRUN: string = ''; (* ������ ($%d) ������� ��� ������ � ������ � %d *)
	rsTunelDestroy: string = ''; (* ������ ($%d) ��������� *)
	rsTunelConnecting: string = ''; (* ������ ($%d), ��������� ����� � %d / ���������� ����� � %d, ���������� � %s:%d ..... *)
	rsTunelConnected: string = ''; (* ������ ($%d), ��������� ����� � %d / ���������� ����� � %d, ���������� ����������� � %s:%d *)
	rsTunelTimeout: string = ''; (* ������ ($%d), ������ ���������� �� �������� *)


	rsInjectConnectIntercepted: string = ''; (* (Inject.dll) ���������� ������� �� %d.%d.%d.%d:%d *)
	rsInjectConnectInterceptOff: string = ''; (* (Inject.dll) ������� �� %d.%d.%d.%d:%d ������� (�������� ��������) *)
	rsInjectConnectInterceptedIgnoder: string = ''; (* (Inject.dll) ������� �� %d.%d.%d.%d:%d �������������� *)

	rsTunelServerDisconnect: string = ''; (* ������ ($%d) ���������� �� ������� *)
	rsTunelClientDisconnect: string = ''; (* ������ ($%d) ���������� �� ������� *)


	rsSocketEngineNewConnection: string = ''; (* ServerListen: ���������� ����� ����������. *)
	rsTsocketEngineError: string = ''; (* ������: %s *)
	rsTsocketEngineSocketError: string = ''; (* �� ������: %d ������: %d: %s  *)

	rsSavingPacketLog: string = ''; (* ��������� ��� �������... *)
	rsConnectionName: string = ''; (* ��� ���������� ��� ������ ($%d): %s *)

	rsClientPatched0: string = ''; (* ������ ��������� ����� ������ %S (%s) *)
	rsClientPatched1: string = ''; (* ������� ��������� ����� ������ %S (%s) *)
	rsClientPatched2: string = ''; (* ������������� ��������� ����� ������ %S (%s) *)
  
	rsUnLoadDllSuccessfully: string = ''; (* ���������� %s ������� ��������� *)
	rsLoadDllUnSuccessful: string = ''; (* ���������� %s ����������� ��� ������������� ������ ����������� *)
	rsLoadDllSuccessfully: string = ''; (* ������� ��������� %s *)
	rsStartLocalServer: string = ''; (* �� %d ��������������� ��������� ������ *)
	rsFailedLocalServer: string = ''; (* �� ������� ���������������� ��������� ������ �� ���� %d
�������� ���� ���� ����� ������ ����������� *)

	rsLSPConnectionDetected: string = ''; (* (LSP) ���������� ���������� (����� %d) IP/port %s:%d. %s *)
	rsLSPConnectionWillbeIntercepted: string = ''; (* ���������� ����� ����������� *)
	rsLSPConnectionWillbeIgnored: string = ''; (* ���������� ����� ��������������� *)
	rsLSPDisconnectDetected: string = ''; (* (LSP) ���������� ������� (����� %d) *)

	RsAppError: string = ''; (* %s - ������ ���������� *)
	RsExceptionClass: string = ''; (* �����: %s *)
	RsExceptionMessage: string = ''; (* ���������: %s *)
	RsExceptionAddr: string = ''; (* �����: %p *)
	RsStackList: string = ''; (* Stack list, generated %s *)
	RsModulesList: string = ''; (* List of loaded modules: *)
	RsOSVersion: string = ''; (* System   : %s %s, Version: %d.%d, Build: %x, "%s" *)
	RsProcessor: string = ''; (* Processor: %s, %s, %d MHz *)
	RsMemory: string = ''; (* Memory: %d; free %d *)
	RsScreenRes: string = ''; (* Display  : %dx%d pixels, %d bpp *)
	RsActiveControl: string = ''; (* Active Controls hierarchy: *)
	RsThread: string = ''; (* Thread: %s *)
	RsMissingVersionInfo: string = ''; (* (no version info) *)
	RsMainThreadCallStack: string = ''; (* Call stack for main thread *)
	RsThreadCallStack: string = ''; (* Call stack for thread %s *)

implementation

end.


