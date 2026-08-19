# IO Engineering helpers

`ioe_ipc.ps1` drives the separately installed ctrlX IO Engineering 2.6.4
ScriptEngine. It must not be used to open the PLC project. Follow the shutdown
and modal-dialog rules documented in `AGENTS.md` and the shared IOE playbook.

`Install-EtherCatEsi.ps1` installs an EtherCAT ESI through the official IO
Engineering device-repository API. It uses a unique temporary IPC session,
does not open a project, verifies the exact device identity, and closes IOE
gracefully. Close any manually opened IO Engineering window before running it.

Station010 Kistler 5867C example:

```powershell
.\scripts\ioe\Install-EtherCatEsi.ps1 `
  -EsiPath '..\Technical Docs\5867c-maxymos-bl-fieldbus-descr-ec-pn-eip-25.1.0\EtherCAT\Kistler_Type_5867C_V1.xml' `
  -SearchTerm '5867' `
  -ExpectedName 'maXYmos BL 5867C' `
  -ExpectedVendor 'Kistler' `
  -ExpectedDeviceId '58A_0000E52F00000001' `
  -ExpectedVersion 'Revision=16#00000001'
```

The PLE device repository is not the EtherCAT ESI repository. On the verified
PLE 2.6.8 installation its REST endpoint has no EtherCAT converter plug-in;
install fieldbus XML only through IO Engineering.
