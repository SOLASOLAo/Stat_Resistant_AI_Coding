using Bpp.ResistantStation.Hmi.Configuration;

namespace Bpp.ResistantStation.Hmi.Services;

public sealed class MockStationDataSource(HmiSettings settings) : IStationDataSource
{
    private CancellationTokenSource? _loopCancellation;
    private Task? _loopTask;
    private int _tick;
    private byte _modeId = 4;
    private bool _modeRequestsEnabled;
    private bool _stationRunning;
    private bool _stepMode;
    private string? _manualUnit;
    private string? _manualFunction;

    public event EventHandler<ConnectionStateChangedEventArgs>? ConnectionStateChanged;
    public event EventHandler<NodeValueChangedEventArgs>? NodeValueChanged;

    public bool IsConnected { get; private set; }
    public bool SupportsModeRequests => _modeRequestsEnabled;
    public bool SupportsStationCommands => IsConnected;
    public bool SupportsManualFunctions => IsConnected;

    public Task ConnectAsync(ConnectionOptions options, CancellationToken cancellationToken)
    {
        if (IsConnected)
        {
            return Task.CompletedTask;
        }

        IsConnected = true;
        _modeRequestsEnabled = settings.ModeControl.Enabled && options.EnableModeRequests;
        _loopCancellation = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        ConnectionStateChanged?.Invoke(this, new ConnectionStateChangedEventArgs(
            true,
            "Offline demonstration source",
            DateTimeOffset.Now));
        PublishSnapshot();
        _loopTask = RunAsync(_loopCancellation.Token);
        return Task.CompletedTask;
    }

    public async Task DisconnectAsync(CancellationToken cancellationToken)
    {
        if (!IsConnected)
        {
            return;
        }

        _loopCancellation?.Cancel();
        if (_loopTask is not null)
        {
            try
            {
                await _loopTask.WaitAsync(cancellationToken);
            }
            catch (OperationCanceledException)
            {
                // Expected during shutdown.
            }
        }

        IsConnected = false;
        _modeRequestsEnabled = false;
        _stationRunning = false;
        _stepMode = false;
        _manualUnit = null;
        _manualFunction = null;
        ConnectionStateChanged?.Invoke(this, new ConnectionStateChangedEventArgs(
            false,
            "Demonstration source stopped",
            DateTimeOffset.Now));
    }

    public Task<ModeRequestResult> RequestModeAsync(
        byte modeId,
        CancellationToken cancellationToken)
    {
        if (!_modeRequestsEnabled ||
            !settings.ModeControl.AllowedModeIds.Contains(modeId))
        {
            return Task.FromResult(new ModeRequestResult(false, modeId, "Unsupported mode ID."));
        }

        _modeId = modeId;
        _stationRunning = false;
        _stepMode = false;
        _manualUnit = null;
        _manualFunction = null;
        Publish("ModeId", modeId);
        Publish("ModeRelease", true);
        return Task.FromResult(new ModeRequestResult(
            true,
            modeId,
            "Demo mode changed."));
    }

    public Task<ControlRequestResult> RequestStationCommandAsync(
        StationCommand command,
        CancellationToken cancellationToken)
    {
        if (!IsConnected || _modeId == 3)
        {
            return Task.FromResult(new ControlRequestResult(
                false,
                "Chain commands require an active Automatic, Homing or Change-over mode."));
        }

        switch (command)
        {
            case StationCommand.Start:
                _stationRunning = true;
                break;
            case StationCommand.Stop:
                _stationRunning = false;
                break;
            case StationCommand.EnableStepMode when _modeId == 1:
                _stepMode = true;
                break;
            case StationCommand.DisableStepMode when _modeId == 1:
                _stepMode = false;
                break;
            case StationCommand.StepPulse when _modeId == 1 && _stepMode && _stationRunning:
                _tick += 12;
                break;
            default:
                return Task.FromResult(new ControlRequestResult(
                    false,
                    "This command is not released in the current demo state."));
        }

        PublishSnapshot();
        return Task.FromResult(new ControlRequestResult(
            true,
            $"Demo command accepted: {command}."));
    }

    public Task<ControlRequestResult> SetManualFunctionAsync(
        string unitKey,
        string functionKey,
        bool execute,
        CancellationToken cancellationToken)
    {
        if (!IsConnected || _modeId != 3)
        {
            return Task.FromResult(new ControlRequestResult(
                false,
                "Unit manual functions require Manual mode."));
        }

        if (execute)
        {
            _manualUnit = unitKey;
            _manualFunction = functionKey;
        }
        else if (string.Equals(_manualUnit, unitKey, StringComparison.Ordinal) &&
                 string.Equals(_manualFunction, functionKey, StringComparison.Ordinal))
        {
            _manualUnit = null;
            _manualFunction = null;
        }

        PublishSnapshot();
        return Task.FromResult(new ControlRequestResult(
            true,
            execute ? "Demo manual function started." : "Demo manual function released."));
    }

    public async ValueTask DisposeAsync()
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(2));
        await DisconnectAsync(timeout.Token);
        _loopCancellation?.Dispose();
    }

    private async Task RunAsync(CancellationToken cancellationToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMilliseconds(
            Math.Max(settings.PublishingIntervalMs, 250)));

        while (await timer.WaitForNextTickAsync(cancellationToken))
        {
            _tick++;
            PublishSnapshot();
        }
    }

    private void PublishSnapshot()
    {
        var phase = (_tick / 12) % 4;
        Publish("ModeId", _modeId);
        Publish("ModeRelease", true);
        Publish("IsRunning", _stationRunning);
        Publish("IsStopping", false);
        Publish("ExecState", _stationRunning ? 32 : 16);
        Publish("ModeRunning", _stationRunning);
        Publish("StartVisible", _modeId != 3 && !_stationRunning);
        Publish("StopVisible", _modeId != 3 && _stationRunning);
        Publish("StepVisible", _modeId == 1);
        Publish("IsStepping", _stepMode);
        Publish("ManualFunctionsActive", _modeId == 3);
        Publish("ManualFunctionRunning", _manualFunction is not null);
        Publish("Token", settings.ModeControl.PanelToken);
        Publish("AutoInfoLine", _stationRunning && _modeId == 1 ? phase switch
        {
            0 => 4,
            1 => 10,
            2 => 12,
            _ => 16
        } : _stationRunning && _modeId is 4 or 5 ? phase switch
        {
            0 => 2,
            1 => 14,
            _ => 16
        } : 0);
        Publish("IsInHomePosition", phase is 0 or 3);
        Publish("StationIsEmpty", true);
        Publish("BusOk", true);
        Publish("MasterOk", true);
        Publish("SlavesOk", true);
        Publish("TopologyNotOk", false);
        Publish("ConfiguredSlaves", (uint)9);
        Publish("DetectedSlaves", (uint)9);
        Publish("LostFrames", (uint)0);
        Publish("SlaveAddress", Enumerable.Range(1001, 9).Select(value => (ushort)value).ToArray());
        Publish("SlaveDeviceState", Enumerable.Repeat((byte)0x08, 9).ToArray());
        Publish("SlaveLinkState", Enumerable.Repeat((byte)0x00, 9).ToArray());
        Publish("SlaveWcState", Enumerable.Repeat(false, 9).ToArray());
        Publish("SlaveWcStateErrorCnt", Enumerable.Repeat((uint)0, 9).ToArray());

        foreach (var node in settings.Nodes.Where(node => node.Category == "io"))
        {
            Publish(node.Key, (_tick / 8 + Math.Abs(node.Key.GetHashCode())) % 3 != 0);
        }

        // Publish semantic demo states after raw I/O so shared node keys remain deterministic.
        Publish("SafetyDoorBase", phase is 0 or 3);
        Publish("SafetyDoorWork", phase is 1 or 2);
        Publish("PressingCylinderBase", phase is not 2);
        Publish("PressingCylinderWork", phase is 2);
        Publish("ResistantUnitState", 4);
        Publish("KistlerUnitState", 4);
        Publish("FixtureLeft", phase == 0);
        Publish("FixtureMiddle", phase is 1 or 2);
        Publish("FixtureRight", phase == 3);
        Publish("ProductSensorA", true);
        Publish("ProductSensorB", true);
        Publish("EmergencyCircuitOk", true);
        Publish("MaintenanceCircuitOk", true);
        Publish("SafetyDoorCircuitOk", true);
        Publish("AllSafetyCircuitsOk", true);

        PublishManualFunction("Wp100", "Home", false);
        PublishManualFunction("Wp100", "DeleteWpcData", false);
        PublishManualFunction("Wp100K101SafetyDoor", "MoveBasPos", true);
        PublishManualFunction("Wp100K101SafetyDoor", "MoveWrkPos", true);
        PublishManualFunction("Wp100K102PressingCylinder", "MoveBasPos", true);
        PublishManualFunction("Wp100K102PressingCylinder", "MoveWrkPos", true);
        PublishManualFunction("Wp100A103ResistantDetector", "SetRange", true);
        PublishManualFunction("Wp100A103ResistantDetector", "StartMeas", true);
        foreach (var action in new[]
                 {
                     "Measure", "LockKeyboard", "UnlockKeyboard", "SetProgram",
                     "ZeroX", "TareY", "ReadData", "WriteData"
                 })
        {
            PublishManualFunction("Wp100A104Kistler", action, true);
        }

        Publish("StationNo", 10);
        Publish("ComputerName", "IPC-STATION010");
        Publish("ScannerHost", "192.168.0.30");
        Publish("ScannerPort", (uint)9004);
        Publish("BursterHost", "192.168.0.40");
        Publish("BursterPort", (uint)5000);
        Publish("ProcessNo", 1);
        Publish("ProcessName", "Resistance test");
        Publish("ProcessDescription", "Three-position resistance and force test");
        Publish("MesIp", "192.168.0.20");
        Publish("MesPort", 8080);
        Publish("MesActive", 1);
        Publish("PressDelayTime", 500);

        Publish("AxisR", new[] { 0.0f, 120.0f, 240.0f });
        Publish("AxisX", new[] { 0.0f, 100.0f, 200.0f, 300.0f, 400.0f });
        Publish("AxisY", new[] { 0.0f, 20.0f, 40.0f, 60.0f, 80.0f });
        Publish("AxisZ", new[] { 0.0f, 5.0f, 10.0f, 15.0f, 20.0f });
        Publish("VerticalDistance", 12.5f);
        Publish("VerticalAmount", (short)3);
        Publish("MinProcessTime", 5_000);
        Publish("PartCycleTime", 20);

        Publish("KistlerReady", true);
        Publish("KistlerProgram", (byte)1);
        Publish("KistlerAlarm", false);
        Publish("KistlerWarning", false);
        Publish("KistlerNoPass", phase == 3);
        Publish("KistlerForce", 1_245.6f + phase * 8.3f);
        Publish("KistlerStroke", 18.42f + phase * 0.1f);

        Publish("PublicEventList", new Dictionary<string, object?>
        {
            ["Entry"] = new object[]
            {
                new Dictionary<string, object?>
                {
                    ["InstanceId"] = (uint)1,
                    ["Number"] = 60,
                    ["Class"] = (uint)2,
                    ["Source"] = "Wp100",
                    ["AddText"] = "Move fixture to the requested position",
                    ["DtEntry"] = DateTime.UtcNow.AddSeconds(-2),
                    ["DtClear"] = DateTime.UnixEpoch,
                    ["EntryOrder"] = (uint)1
                },
                new Dictionary<string, object?>
                {
                    ["InstanceId"] = (uint)2,
                    ["Number"] = 61,
                    ["Class"] = (uint)2,
                    ["Source"] = "Wp100",
                    ["AddText"] = "Cleared demo event must stay hidden",
                    ["DtEntry"] = DateTime.UtcNow.AddSeconds(-5),
                    ["DtClear"] = DateTime.UtcNow.AddSeconds(-1),
                    ["EntryOrder"] = (uint)2
                }
            }
        });
    }

    private void Publish(string key, object value)
    {
        NodeValueChanged?.Invoke(this, new NodeValueChangedEventArgs(
            key,
            value,
            true,
            "Good (demo)",
            DateTimeOffset.Now));
    }

    private void PublishManualFunction(string unitKey, string functionKey, bool released)
    {
        var prefix = $"Manual.{unitKey}.{functionKey}";
        Publish($"{prefix}.Release", released);
        Publish(
            $"{prefix}.Running",
            string.Equals(_manualUnit, unitKey, StringComparison.Ordinal) &&
            string.Equals(_manualFunction, functionKey, StringComparison.Ordinal));
    }
}
