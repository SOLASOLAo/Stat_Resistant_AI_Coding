using Bpp.ResistantStation.Hmi.Configuration;

namespace Bpp.ResistantStation.Hmi.Services;

public sealed class MockStationDataSource(HmiSettings settings) : IStationDataSource
{
    private readonly IReadOnlyDictionary<string, HmiNodeDefinition> _configuredNodes =
        settings.Nodes.Where(node => node.Enabled).ToDictionary(node => node.Key, StringComparer.Ordinal);
    private readonly int[] _autoInfoIndexes = settings.AutoInfoLines
        .Select(line => line.Index)
        .ToArray();
    private readonly HashSet<string> _publishedKeys = new(StringComparer.Ordinal);
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
        // DEMO never writes to OPC UA, so it remains navigable even when real
        // mode writes are disabled in the selected project configuration.
        _modeRequestsEnabled = options.EnableModeRequests;
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
        _publishedKeys.Clear();
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
        var idleInfoIndex = _autoInfoIndexes.FirstOrDefault();
        var runningInfoIndex = _autoInfoIndexes.Length > 1
            ? _autoInfoIndexes[1 + ((_tick / 12) % (_autoInfoIndexes.Length - 1))]
            : idleInfoIndex;
        Publish("AutoInfoLine", _stationRunning ? runningInfoIndex : idleInfoIndex);
        Publish("IsInHomePosition", phase is 0 or 3);
        Publish("StationIsEmpty", true);
        Publish("BusOk", true);
        Publish("MasterOk", true);
        Publish("SlavesOk", true);
        Publish("TopologyNotOk", false);
        var slaveCount = settings.Fieldbus.Slaves.Count;
        Publish("ConfiguredSlaves", (uint)slaveCount);
        Publish("DetectedSlaves", (uint)slaveCount);
        Publish("LostFrames", (uint)0);
        Publish("SlaveAddress", Enumerable.Range(1001, slaveCount).Select(value => (ushort)value).ToArray());
        Publish("SlaveDeviceState", Enumerable.Repeat((byte)0x08, slaveCount).ToArray());
        Publish("SlaveLinkState", Enumerable.Repeat((byte)0x00, slaveCount).ToArray());
        Publish("SlaveWcState", Enumerable.Repeat(false, slaveCount).ToArray());
        Publish("SlaveWcStateErrorCnt", Enumerable.Repeat((uint)0, slaveCount).ToArray());

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

        Publish("BursterUpperRange", (short)0);
        Publish("BursterLowerRange", (short)0);
        Publish("BursterUpperLimit", 2.20f);
        Publish("BursterLowerLimit", 1.80f);
        Publish("BursterReadTemperature", true);
        Publish("BursterResistOk", phase != 3);
        Publish("BursterOutOfLimit", phase == 3);
        Publish("BursterResistance", 1.96f + phase * 0.03f);
        Publish("BursterTemperature", 23.6f + phase * 0.2f);

        Publish("KistlerProgramRequest", (byte)2);
        Publish("KistlerMeasuringTimeout", (uint)5_000);
        Publish("KistlerEndMeasurement", false);
        Publish("KistlerScreenLocked", true);
        Publish("KistlerReady", true);
        Publish("KistlerSignal1", phase is 1 or 2);
        Publish("KistlerSignal2", phase is 2 or 3);
        Publish("KistlerProgram", (byte)2);
        Publish("KistlerAlarm", false);
        Publish("KistlerWarning", false);
        Publish("KistlerNoPass", phase == 3);
        Publish("KistlerOk", phase != 3);
        Publish("KistlerNok", phase == 3);
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
                    ["Source"] = settings.StationId,
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
                    ["Source"] = settings.StationId,
                    ["AddText"] = "Cleared demo event must stay hidden",
                    ["DtEntry"] = DateTime.UtcNow.AddSeconds(-5),
                    ["DtClear"] = DateTime.UtcNow.AddSeconds(-1),
                    ["EntryOrder"] = (uint)2
                }
            }
        });

        foreach (var definition in _configuredNodes.Values.Where(
                     definition => !_publishedKeys.Contains(definition.Key)))
        {
            Publish(definition.Key, CreateDemoValue(definition, phase));
        }
    }

    private object CreateDemoValue(HmiNodeDefinition definition, int phase)
    {
        var manualAction = settings.ManualUnits
            .SelectMany(unit => unit.Actions.Select(action => (unit.Key, Action: action)))
            .FirstOrDefault(item =>
                string.Equals(item.Action.ReleaseNodeKey, definition.Key, StringComparison.Ordinal));
        if (manualAction.Action is not null)
        {
            return true;
        }

        var runningAction = settings.ManualUnits
            .SelectMany(unit => unit.Actions.Select(action => (unit.Key, Action: action)))
            .FirstOrDefault(item =>
                string.Equals(item.Action.RunningNodeKey, definition.Key, StringComparison.Ordinal));
        if (runningAction.Action is not null)
        {
            return string.Equals(_manualUnit, runningAction.Key, StringComparison.Ordinal) &&
                   string.Equals(_manualFunction, runningAction.Action.Key, StringComparison.Ordinal);
        }

        if (definition.Category == "unit")
        {
            return (byte)4;
        }

        return definition.DataType switch
        {
            "Boolean" => phase % 2 == 0,
            "Byte" => (byte)phase,
            "Int16" => (short)phase,
            "UInt16" => (ushort)phase,
            "Int32" => phase,
            "UInt32" => (uint)phase,
            "Single" => 10.0f + phase,
            "Double" => 10.0d + phase,
            "String" => $"Demo {definition.English}",
            "Byte[]" => Enumerable.Repeat((byte)phase, Math.Max(1, settings.Fieldbus.Slaves.Count)).ToArray(),
            "Boolean[]" => Enumerable.Repeat(false, Math.Max(1, settings.Fieldbus.Slaves.Count)).ToArray(),
            "UInt16[]" => Enumerable.Range(1001, Math.Max(1, settings.Fieldbus.Slaves.Count))
                .Select(value => (ushort)value).ToArray(),
            "UInt32[]" => Enumerable.Repeat((uint)0, Math.Max(1, settings.Fieldbus.Slaves.Count)).ToArray(),
            _ => 0
        };
    }

    private void Publish(string key, object? value)
    {
        if (!_configuredNodes.ContainsKey(key))
        {
            return;
        }

        _publishedKeys.Add(key);
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
