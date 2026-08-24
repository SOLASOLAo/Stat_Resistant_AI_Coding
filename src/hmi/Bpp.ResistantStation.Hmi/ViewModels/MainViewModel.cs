using System.Collections;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Windows;
using System.Windows.Threading;
using Bpp.ResistantStation.Hmi.Configuration;
using Bpp.ResistantStation.Hmi.Services;

namespace Bpp.ResistantStation.Hmi.ViewModels;

public sealed class MainViewModel : ObservableObject, IAsyncDisposable
{
    private readonly HmiSettings _settings;
    private readonly IReadOnlyDictionary<int, LocalizedAutoInfo> _autoInfo;
    private readonly HashSet<string> _badNodes = new(StringComparer.Ordinal);
    private readonly IReadOnlyDictionary<string, DataValueRow> _dataRows;
    private readonly IReadOnlyDictionary<string, IoChannelRow> _ioRows;
    private readonly DispatcherTimer _freshnessTimer;
    private IStationDataSource? _dataSource;
    private bool _isConnected;
    private bool _isBusy;
    private bool _isDemo;
    private bool _hasReceivedData;
    private bool _isStale;
    private int _selectedPageIndex;
    private string _connectionMessage = "Not connected / 未连接";
    private DateTimeOffset _lastUpdate = DateTimeOffset.Now;
    private int _modeId;
    private bool _modeReleased;
    private bool _isRunning;
    private bool _isStopping;
    private int _execState;
    private int _token;
    private int _autoInfoIndex;
    private bool _isInHomePosition;
    private bool _busOk;
    private bool _safetyDoorBase;
    private bool _safetyDoorWork;
    private bool _pressingCylinderBase;
    private bool _pressingCylinderWork;
    private bool _fixtureLeft;
    private bool _fixtureMiddle;
    private bool _fixtureRight;
    private bool _productSensorA;
    private bool _productSensorB;
    private bool _emergencyCircuitOk;
    private bool _maintenanceCircuitOk;
    private bool _safetyDoorCircuitOk;
    private bool _allSafetyCircuitsOk;
    private int _resistantUnitState;
    private int _kistlerUnitState;
    private bool _stationIsEmpty;
    private bool _masterOk;
    private bool _slavesOk;
    private bool _topologyNotOk;
    private int _configuredSlaves;
    private int _detectedSlaves;
    private uint _lostFrames;
    private string _modeRequestMessage = "Mode control ready / 模式控制就绪";
    private string _eventDecodeMessage = "Waiting for PublicEventList / 等待报警列表";

    public MainViewModel(HmiSettings settings)
    {
        _settings = settings;
        _autoInfo = settings.AutoInfoLines.ToDictionary(item => item.Index);
        EndpointUrl = settings.EndpointUrl;
        StationId = settings.StationId;
        StationName = settings.StationName;
        EtherCatSlaves = new ObservableCollection<EtherCatSlaveRow>(
            settings.Fieldbus.Slaves.OrderBy(slave => slave.Index).Select(slave => new EtherCatSlaveRow(slave)));
        IoChannels = new ObservableCollection<IoChannelRow>(
            settings.Fieldbus.Channels
                .OrderBy(channel => channel.SlaveIndex)
                .ThenBy(channel => channel.Channel)
                .Select(channel => new IoChannelRow(channel)));
        StationDataItems = CreateDataRows(settings, "station-data");
        TypeDataItems = CreateDataRows(settings, "type-data");
        DeviceDataItems = CreateDataRows(settings, "device-data");
        ActiveEvents = [];
        _dataRows = StationDataItems
            .Concat(TypeDataItems)
            .Concat(DeviceDataItems)
            .ToDictionary(row => row.Key, StringComparer.Ordinal);
        _ioRows = IoChannels.ToDictionary(row => row.NodeKey, StringComparer.Ordinal);
        _freshnessTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(500)
        };
        _freshnessTimer.Tick += OnFreshnessTick;
        _freshnessTimer.Start();
        RefreshDerivedProperties();
    }

    public ObservableCollection<EtherCatSlaveRow> EtherCatSlaves { get; }

    public ObservableCollection<IoChannelRow> IoChannels { get; }

    public ObservableCollection<DataValueRow> StationDataItems { get; }

    public ObservableCollection<DataValueRow> TypeDataItems { get; }

    public ObservableCollection<DataValueRow> DeviceDataItems { get; }

    public ObservableCollection<PublicEventRow> ActiveEvents { get; }

    public string StationId { get; }

    public string StationName { get; }

    public string EndpointUrl { get; }

    public bool IsConnected
    {
        get => _isConnected;
        private set
        {
            if (SetProperty(ref _isConnected, value))
            {
                RefreshDataQuality();
                RaisePropertyChanged(nameof(CanRequestMode));
            }
        }
    }

    public bool IsBusy
    {
        get => _isBusy;
        private set
        {
            if (SetProperty(ref _isBusy, value))
            {
                RaisePropertyChanged(nameof(CanRequestMode));
            }
        }
    }

    public bool IsDemo
    {
        get => _isDemo;
        private set => SetProperty(ref _isDemo, value);
    }

    public string ConnectionMessage
    {
        get => _connectionMessage;
        private set => SetProperty(ref _connectionMessage, value);
    }

    public string LastUpdateText => _lastUpdate.ToString("yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture);

    public int SelectedPageIndex
    {
        get => _selectedPageIndex;
        private set
        {
            if (SetProperty(ref _selectedPageIndex, value))
            {
                RaisePropertyChanged(nameof(PageName));
                RaisePropertyChanged(nameof(WindowTitle));
            }
        }
    }

    public string PageName => SelectedPageIndex switch
    {
        1 => "Manual",
        2 => "Events",
        3 => "I/O",
        4 => "Data",
        _ => "Overview"
    };

    public string WindowTitle => $"BPP Resistance Station HMI — {PageName}";

    public bool IsDataUnavailable =>
        !IsConnected ||
        !_hasReceivedData ||
        IsStale ||
        _badNodes.Count > 0;

    public bool IsStale
    {
        get => _isStale;
        private set
        {
            if (SetProperty(ref _isStale, value))
            {
                RefreshDataQuality();
            }
        }
    }

    public string DataQualityText => !IsConnected
        ? "PLC DATA OFFLINE / PLC 数据未连接"
        : !_hasReceivedData
            ? "WAITING FOR PLC DATA / 正在等待 PLC 数据"
            : IsStale
                ? "STALE PLC DATA / PLC 数据已超时"
            : _badNodes.Count > 0
                ? $"BAD DATA QUALITY: {string.Join(", ", _badNodes.Order())}"
                : "DATA CURRENT / 数据有效";

    public string ModeRequestMessage
    {
        get => _modeRequestMessage;
        private set => SetProperty(ref _modeRequestMessage, value);
    }

    public bool CanRequestMode =>
        !IsDataUnavailable &&
        !IsBusy &&
        ModeRequestSafetyReady &&
        _dataSource?.SupportsModeRequests == true;

    public string EventDecodeMessage
    {
        get => _eventDecodeMessage;
        private set => SetProperty(ref _eventDecodeMessage, value);
    }

    public bool HasActiveEvents => ActiveEvents.Count > 0;

    public int ModeId
    {
        get => _modeId;
        private set
        {
            if (SetProperty(ref _modeId, value))
            {
                RaisePropertyChanged(nameof(ModeName));
            }
        }
    }

    public string ModeName => ModeId switch
    {
        1 => "AUTOMATIC / 自动",
        3 => "MANUAL / 手动",
        4 => "HOMING / 回原位",
        5 => "CHANGE-OVER / 换型",
        _ => "NO MODE / 无模式"
    };

    public bool ModeReleased
    {
        get => _modeReleased;
        private set => SetProperty(ref _modeReleased, value);
    }

    public bool IsRunning
    {
        get => _isRunning;
        private set
        {
            if (SetProperty(ref _isRunning, value))
            {
                RaisePropertyChanged(nameof(RunStateText));
            }
        }
    }

    public bool IsStopping
    {
        get => _isStopping;
        private set
        {
            if (SetProperty(ref _isStopping, value))
            {
                RaisePropertyChanged(nameof(RunStateText));
            }
        }
    }

    public string RunStateText => IsStopping
        ? "STOPPING / 正在停止"
        : IsRunning
            ? "RUNNING / 运行中"
            : ExecState switch
            {
                1 => "UNKNOWN / 未知",
                2 => "NOT READY / 未就绪",
                4 => "DEACTIVATED / 未激活",
                8 => "INITIALIZING / 初始化",
                16 => "READY / 就绪",
                32 => "RUNNING / 运行中",
                64 => "DONE / 完成",
                128 => "ERROR / 故障",
                256 => "CANCELLED / 已取消",
                _ => $"STATE {ExecState} / 状态 {ExecState}"
            };

    public int ExecState
    {
        get => _execState;
        private set
        {
            if (SetProperty(ref _execState, value))
            {
                RaisePropertyChanged(nameof(RunStateText));
            }
        }
    }

    public int Token
    {
        get => _token;
        private set => SetProperty(ref _token, value);
    }

    public int AutoInfoIndex
    {
        get => _autoInfoIndex;
        private set
        {
            if (SetProperty(ref _autoInfoIndex, value))
            {
                RaisePropertyChanged(nameof(AutoInfoChinese));
                RaisePropertyChanged(nameof(AutoInfoEnglish));
            }
        }
    }

    public string AutoInfoChinese => _autoInfo.TryGetValue(AutoInfoIndex, out var info)
        ? info.Chinese
        : $"未知步骤 {AutoInfoIndex}";

    public string AutoInfoEnglish => _autoInfo.TryGetValue(AutoInfoIndex, out var info)
        ? info.English
        : $"Unknown step {AutoInfoIndex}";

    public bool IsInHomePosition
    {
        get => _isInHomePosition;
        private set => SetProperty(ref _isInHomePosition, value);
    }

    public bool BusOk
    {
        get => _busOk;
        private set => SetProperty(ref _busOk, value);
    }

    public bool StationIsEmpty
    {
        get => _stationIsEmpty;
        private set => SetProperty(ref _stationIsEmpty, value);
    }

    public bool MasterOk
    {
        get => _masterOk;
        private set => SetProperty(ref _masterOk, value);
    }

    public bool SlavesOk
    {
        get => _slavesOk;
        private set => SetProperty(ref _slavesOk, value);
    }

    public bool TopologyNotOk
    {
        get => _topologyNotOk;
        private set => SetProperty(ref _topologyNotOk, value);
    }

    public int ConfiguredSlaves
    {
        get => _configuredSlaves;
        private set => SetProperty(ref _configuredSlaves, value);
    }

    public int DetectedSlaves
    {
        get => _detectedSlaves;
        private set => SetProperty(ref _detectedSlaves, value);
    }

    public uint LostFrames
    {
        get => _lostFrames;
        private set => SetProperty(ref _lostFrames, value);
    }

    public bool SafetyDoorBase
    {
        get => _safetyDoorBase;
        private set
        {
            if (SetProperty(ref _safetyDoorBase, value))
            {
                RaisePropertyChanged(nameof(SafetyDoorState));
            }
        }
    }

    public bool SafetyDoorWork
    {
        get => _safetyDoorWork;
        private set
        {
            if (SetProperty(ref _safetyDoorWork, value))
            {
                RaisePropertyChanged(nameof(SafetyDoorState));
            }
        }
    }

    public string SafetyDoorState => SafetyDoorBase
        ? "OPEN / 原位"
        : SafetyDoorWork
            ? "CLOSED / 工作位"
            : "MOVING / 中间位";

    public bool PressingCylinderBase
    {
        get => _pressingCylinderBase;
        private set
        {
            if (SetProperty(ref _pressingCylinderBase, value))
            {
                RaisePropertyChanged(nameof(PressingCylinderState));
            }
        }
    }

    public bool PressingCylinderWork
    {
        get => _pressingCylinderWork;
        private set
        {
            if (SetProperty(ref _pressingCylinderWork, value))
            {
                RaisePropertyChanged(nameof(PressingCylinderState));
            }
        }
    }

    public string PressingCylinderState => PressingCylinderBase
        ? "UP / 上升到位"
        : PressingCylinderWork
            ? "DOWN / 下降到位"
            : "MOVING / 运动中";

    public bool ProductPresent => _productSensorA && _productSensorB;

    public string ProductState => ProductPresent
        ? "PART PRESENT / 产品已放置"
        : "PART MISSING / 产品缺失";

    public string FixturePosition
    {
        get
        {
            var active = new[] { _fixtureLeft, _fixtureMiddle, _fixtureRight }.Count(value => value);
            if (active != 1)
            {
                return active == 0 ? "UNKNOWN / 未知" : "INVALID / 信号冲突";
            }

            return _fixtureLeft
                ? "LEFT / 左"
                : _fixtureMiddle
                    ? "MIDDLE / 中"
                    : "RIGHT / 右";
        }
    }

    public bool SafetyReady =>
        _emergencyCircuitOk &&
        _maintenanceCircuitOk &&
        _safetyDoorCircuitOk &&
        _allSafetyCircuitsOk;

    public string SafetyState => SafetyReady
        ? "ALL CIRCUITS READY / 安全回路正常"
        : "SAFETY RELEASE MISSING / 安全回路未释放";

    private bool ModeRequestSafetyReady =>
        _emergencyCircuitOk &&
        _maintenanceCircuitOk;

    public int ResistantUnitState
    {
        get => _resistantUnitState;
        private set
        {
            if (SetProperty(ref _resistantUnitState, value))
            {
                RaisePropertyChanged(nameof(ResistantAvailable));
                RaisePropertyChanged(nameof(ResistantState));
            }
        }
    }

    public bool ResistantAvailable => IsStableUnitState(ResistantUnitState);

    public string ResistantState => DescribeUnitState(ResistantUnitState);

    public int KistlerUnitState
    {
        get => _kistlerUnitState;
        private set
        {
            if (SetProperty(ref _kistlerUnitState, value))
            {
                RaisePropertyChanged(nameof(KistlerAvailable));
                RaisePropertyChanged(nameof(KistlerState));
            }
        }
    }

    public bool KistlerAvailable => IsStableUnitState(KistlerUnitState);

    public string KistlerState => DescribeUnitState(KistlerUnitState);

    public void SelectPage(int pageIndex)
    {
        if (pageIndex is < 0 or > 4)
        {
            throw new ArgumentOutOfRangeException(nameof(pageIndex));
        }

        SelectedPageIndex = pageIndex;
    }

    public async Task<ModeRequestResult> RequestModeAsync(
        byte modeId,
        CancellationToken cancellationToken)
    {
        if (_dataSource is null || !CanRequestMode)
        {
            return new ModeRequestResult(
                false,
                modeId,
                "Mode control is unavailable while PLC data is offline or stale.");
        }

        IsBusy = true;
        RaisePropertyChanged(nameof(CanRequestMode));
        try
        {
            ModeRequestMessage = $"Requesting mode {modeId} / 正在请求模式 {modeId}";
            var result = await _dataSource.RequestModeAsync(modeId, cancellationToken);
            ModeRequestMessage = result.Message;
            return result;
        }
        finally
        {
            IsBusy = false;
            RaisePropertyChanged(nameof(CanRequestMode));
        }
    }

    public async Task ConnectAsync(
        bool useDemo,
        string userName,
        string password,
        bool autoAcceptUntrustedCertificate,
        CancellationToken cancellationToken)
    {
        if (IsBusy)
        {
            return;
        }

        IsBusy = true;
        try
        {
            await ReplaceDataSourceAsync(
                useDemo ? new MockStationDataSource(_settings) : new OpcUaReadOnlyDataSource(_settings),
                cancellationToken);
            IsDemo = useDemo;
            await _dataSource!.ConnectAsync(
                new ConnectionOptions(userName, password, autoAcceptUntrustedCertificate),
                cancellationToken);
        }
        catch (Exception exception)
        {
            ConnectionMessage = exception.GetBaseException().Message;
            IsConnected = false;
            await ReleaseDataSourceAsync(CancellationToken.None);
            throw;
        }
        finally
        {
            IsBusy = false;
        }
    }

    public async Task DisconnectAsync(CancellationToken cancellationToken)
    {
        if (IsBusy)
        {
            return;
        }

        IsBusy = true;
        try
        {
            await ReleaseDataSourceAsync(cancellationToken);
        }
        finally
        {
            IsBusy = false;
        }
    }

    public async ValueTask DisposeAsync()
    {
        _freshnessTimer.Stop();
        _freshnessTimer.Tick -= OnFreshnessTick;
        await ReleaseDataSourceAsync(CancellationToken.None);
    }

    private async Task ReplaceDataSourceAsync(
        IStationDataSource dataSource,
        CancellationToken cancellationToken)
    {
        await ReleaseDataSourceAsync(cancellationToken);
        _dataSource = dataSource;
        _dataSource.ConnectionStateChanged += OnConnectionStateChanged;
        _dataSource.NodeValueChanged += OnNodeValueChanged;
    }

    private async Task ReleaseDataSourceAsync(CancellationToken cancellationToken)
    {
        if (_dataSource is not null)
        {
            _dataSource.ConnectionStateChanged -= OnConnectionStateChanged;
            _dataSource.NodeValueChanged -= OnNodeValueChanged;
            await _dataSource.DisconnectAsync(cancellationToken);
            await _dataSource.DisposeAsync();
            _dataSource = null;
        }

        IsConnected = false;
        IsDemo = false;
        ConnectionMessage = "Disconnected / 未连接";
        ResetLiveValues();
    }

    private void OnConnectionStateChanged(object? sender, ConnectionStateChangedEventArgs eventArgs)
    {
        Dispatch(() =>
        {
            IsConnected = eventArgs.IsConnected;
            ConnectionMessage = eventArgs.Message;
            _lastUpdate = eventArgs.Timestamp;
            RaisePropertyChanged(nameof(LastUpdateText));

            if (!eventArgs.IsConnected)
            {
                ResetLiveValues();
            }
        });
    }

    private void OnNodeValueChanged(object? sender, NodeValueChangedEventArgs eventArgs)
    {
        Dispatch(() =>
        {
            _lastUpdate = eventArgs.SourceTimestamp;
            IsStale = false;
            RaisePropertyChanged(nameof(LastUpdateText));

            if (_dataRows.TryGetValue(eventArgs.Key, out var dataRow))
            {
                dataRow.Update(eventArgs.Value, eventArgs.IsGood, eventArgs.Status);
            }

            if (_ioRows.TryGetValue(eventArgs.Key, out var ioRow))
            {
                ioRow.Update(eventArgs.Value, eventArgs.IsGood, eventArgs.Status);
            }

            if (!eventArgs.IsGood)
            {
                _badNodes.Add(eventArgs.Key);
                ConnectionMessage = $"{eventArgs.Key}: {eventArgs.Status}";
                RefreshDataQuality();
                return;
            }

            _badNodes.Remove(eventArgs.Key);
            _hasReceivedData = true;
            ApplyValue(eventArgs.Key, eventArgs.Value);
            RefreshDataQuality();
        });
    }

    private void ApplyValue(string key, object? value)
    {
        switch (key)
        {
            case "ModeId": ModeId = ToInt32(value); break;
            case "ModeRelease": ModeReleased = ToBoolean(value); break;
            case "IsRunning": IsRunning = ToBoolean(value); break;
            case "IsStopping": IsStopping = ToBoolean(value); break;
            case "ExecState": ExecState = ToInt32(value); break;
            case "Token": Token = ToInt32(value); break;
            case "AutoInfoLine": AutoInfoIndex = ToInt32(value); break;
            case "IsInHomePosition": IsInHomePosition = ToBoolean(value); break;
            case "StationIsEmpty": StationIsEmpty = ToBoolean(value); break;
            case "BusOk": BusOk = ToBoolean(value); break;
            case "MasterOk": MasterOk = ToBoolean(value); break;
            case "SlavesOk": SlavesOk = ToBoolean(value); break;
            case "TopologyNotOk": TopologyNotOk = ToBoolean(value); break;
            case "ConfiguredSlaves": ConfiguredSlaves = ToInt32(value); break;
            case "DetectedSlaves": DetectedSlaves = ToInt32(value); break;
            case "LostFrames": LostFrames = Convert.ToUInt32(value, CultureInfo.InvariantCulture); break;
            case "SlaveAddress": ApplySlaveArray(value, (row, item) => row.Address = ToInt32(item)); break;
            case "SlaveDeviceState": ApplySlaveArray(value, (row, item) => row.DeviceState = ToInt32(item)); break;
            case "SlaveLinkState": ApplySlaveArray(value, (row, item) => row.LinkState = ToInt32(item)); break;
            case "SlaveWcState": ApplySlaveArray(value, (row, item) => row.WorkingCounterInvalid = ToBoolean(item)); break;
            case "SlaveWcStateErrorCnt":
                ApplySlaveArray(value, (row, item) => row.WorkingCounterErrors =
                    Convert.ToUInt32(item, CultureInfo.InvariantCulture));
                break;
            case "SafetyDoorBase": SafetyDoorBase = ToBoolean(value); break;
            case "SafetyDoorWork": SafetyDoorWork = ToBoolean(value); break;
            case "PressingCylinderBase": PressingCylinderBase = ToBoolean(value); break;
            case "PressingCylinderWork": PressingCylinderWork = ToBoolean(value); break;
            case "FixtureLeft": _fixtureLeft = ToBoolean(value); RefreshFixture(); break;
            case "FixtureMiddle": _fixtureMiddle = ToBoolean(value); RefreshFixture(); break;
            case "FixtureRight": _fixtureRight = ToBoolean(value); RefreshFixture(); break;
            case "ProductSensorA": _productSensorA = ToBoolean(value); RefreshProduct(); break;
            case "ProductSensorB": _productSensorB = ToBoolean(value); RefreshProduct(); break;
            case "EmergencyCircuitOk": _emergencyCircuitOk = ToBoolean(value); RefreshSafety(); break;
            case "MaintenanceCircuitOk": _maintenanceCircuitOk = ToBoolean(value); RefreshSafety(); break;
            case "SafetyDoorCircuitOk": _safetyDoorCircuitOk = ToBoolean(value); RefreshSafety(); break;
            case "AllSafetyCircuitsOk": _allSafetyCircuitsOk = ToBoolean(value); RefreshSafety(); break;
            case "ResistantUnitState":
                ResistantUnitState = ToInt32(value);
                break;
            case "KistlerUnitState":
                KistlerUnitState = ToInt32(value);
                break;
            case "PublicEventList":
                ApplyPublicEvents(value);
                break;
        }
    }

    private void ApplySlaveArray(object? value, Action<EtherCatSlaveRow, object?> apply)
    {
        if (value is not IEnumerable values)
        {
            return;
        }

        var items = values.Cast<object?>().ToArray();
        foreach (var row in EtherCatSlaves)
        {
            var arrayIndex = row.Index - 1;
            if (arrayIndex >= 0 && arrayIndex < items.Length)
            {
                apply(row, items[arrayIndex]);
            }
        }
    }

    private void ApplyPublicEvents(object? value)
    {
        if (!PublicEventDecoder.TryDecode(value, out var rows))
        {
            EventDecodeMessage =
                "PublicEventList is subscribed, but this server payload needs one read-only browse/decode acceptance. / 已订阅报警列表，需一次只读联机确认结构解码。";
            return;
        }

        ActiveEvents.Clear();
        foreach (var row in rows)
        {
            ActiveEvents.Add(row);
        }

        EventDecodeMessage = rows.Count == 0
            ? "No active event / 当前无活动报警"
            : $"{rows.Count} active event(s) / {rows.Count} 条活动报警";
        RaisePropertyChanged(nameof(HasActiveEvents));
    }

    private static ObservableCollection<DataValueRow> CreateDataRows(
        HmiSettings settings,
        string category)
    {
        return new ObservableCollection<DataValueRow>(settings.Nodes
            .Where(node => string.Equals(node.Category, category, StringComparison.Ordinal))
            .Select(node => new DataValueRow(node)));
    }

    private void OnFreshnessTick(object? sender, EventArgs eventArgs)
    {
        if (!IsConnected || !_hasReceivedData)
        {
            return;
        }

        IsStale = DateTimeOffset.Now - _lastUpdate >
            TimeSpan.FromMilliseconds(_settings.StaleTimeoutMs);
    }

    private void RefreshDerivedProperties()
    {
        RaisePropertyChanged(nameof(ModeName));
        RaisePropertyChanged(nameof(RunStateText));
        RaisePropertyChanged(nameof(AutoInfoChinese));
        RaisePropertyChanged(nameof(AutoInfoEnglish));
        RaisePropertyChanged(nameof(FixturePosition));
        RaisePropertyChanged(nameof(ProductPresent));
        RaisePropertyChanged(nameof(ProductState));
        RaisePropertyChanged(nameof(SafetyReady));
        RaisePropertyChanged(nameof(SafetyState));
        RaisePropertyChanged(nameof(ResistantAvailable));
        RaisePropertyChanged(nameof(ResistantState));
        RaisePropertyChanged(nameof(KistlerAvailable));
        RaisePropertyChanged(nameof(KistlerState));
        RefreshDataQuality();
    }

    private void ResetLiveValues()
    {
        _badNodes.Clear();
        _hasReceivedData = false;
        IsStale = false;
        ModeId = 0;
        ModeReleased = false;
        IsRunning = false;
        IsStopping = false;
        ExecState = 0;
        Token = 0;
        AutoInfoIndex = 0;
        IsInHomePosition = false;
        StationIsEmpty = false;
        BusOk = false;
        MasterOk = false;
        SlavesOk = false;
        TopologyNotOk = false;
        ConfiguredSlaves = 0;
        DetectedSlaves = 0;
        LostFrames = 0;
        SafetyDoorBase = false;
        SafetyDoorWork = false;
        PressingCylinderBase = false;
        PressingCylinderWork = false;
        _fixtureLeft = false;
        _fixtureMiddle = false;
        _fixtureRight = false;
        _productSensorA = false;
        _productSensorB = false;
        _emergencyCircuitOk = false;
        _maintenanceCircuitOk = false;
        _safetyDoorCircuitOk = false;
        _allSafetyCircuitsOk = false;
        ResistantUnitState = 0;
        KistlerUnitState = 0;
        foreach (var row in EtherCatSlaves)
        {
            row.Reset();
        }

        foreach (var row in IoChannels)
        {
            row.Reset();
        }

        foreach (var row in _dataRows.Values)
        {
            row.Reset();
        }

        ActiveEvents.Clear();
        EventDecodeMessage = "Waiting for PublicEventList / 等待报警列表";
        ModeRequestMessage = "Mode control ready / 模式控制就绪";
        RaisePropertyChanged(nameof(HasActiveEvents));
        RefreshDerivedProperties();
    }

    private void RefreshDataQuality()
    {
        RaisePropertyChanged(nameof(IsDataUnavailable));
        RaisePropertyChanged(nameof(DataQualityText));
        RaisePropertyChanged(nameof(CanRequestMode));
    }

    private void RefreshFixture() => RaisePropertyChanged(nameof(FixturePosition));

    private void RefreshProduct()
    {
        RaisePropertyChanged(nameof(ProductPresent));
        RaisePropertyChanged(nameof(ProductState));
    }

    private void RefreshSafety()
    {
        RaisePropertyChanged(nameof(SafetyReady));
        RaisePropertyChanged(nameof(SafetyState));
        RaisePropertyChanged(nameof(CanRequestMode));
    }

    private static bool ToBoolean(object? value) => value switch
    {
        bool boolean => boolean,
        _ => Convert.ToBoolean(value, CultureInfo.InvariantCulture)
    };

    private static int ToInt32(object? value) => Convert.ToInt32(value, CultureInfo.InvariantCulture);

    private static bool IsStableUnitState(int state) => state is 4 or 8;

    private static string DescribeUnitState(int state) => state switch
    {
        1 => "UNKNOWN / 未知",
        2 => "DISABLED / 已禁用",
        4 => "OPERATIONAL / 运行",
        8 => "STANDBY / 待机",
        18 => "ENTERING DISABLED / 正在禁用",
        20 => "ENTERING OPERATIONAL / 正在进入运行",
        24 => "ENTERING STANDBY / 正在进入待机",
        34 => "LEAVING DISABLED / 正在退出禁用",
        36 => "LEAVING OPERATIONAL / 正在退出运行",
        40 => "LEAVING STANDBY / 正在退出待机",
        _ => "NO DATA / 无数据"
    };

    private static void Dispatch(Action action)
    {
        var dispatcher = Application.Current.Dispatcher;
        if (dispatcher.CheckAccess())
        {
            action();
        }
        else
        {
            dispatcher.Invoke(action);
        }
    }
}
