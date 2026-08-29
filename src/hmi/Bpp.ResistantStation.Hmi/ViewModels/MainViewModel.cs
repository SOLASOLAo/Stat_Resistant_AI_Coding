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
    private readonly IReadOnlyDictionary<byte, ModeDisplayDefinition> _modeDisplays;
    private readonly HashSet<string> _badNodes = new(StringComparer.Ordinal);
    private readonly Dictionary<string, bool> _manualReleaseValues = new(StringComparer.Ordinal);
    private readonly Dictionary<string, bool> _manualRunningValues = new(StringComparer.Ordinal);
    private readonly Dictionary<string, object?> _liveValues = new(StringComparer.Ordinal);
    private readonly IReadOnlyDictionary<string, DeviceFieldRow> _manualDeviceFields;
    private readonly IReadOnlyDictionary<string, DataValueRow> _dataRows;
    private readonly IReadOnlyDictionary<string, IoChannelRow> _ioRows;
    private readonly ILookup<string, OverviewCardRow> _overviewCardsByNodeKey;
    private readonly IReadOnlyDictionary<string, ManualActionRow> _manualActionsByReleaseNodeKey;
    private readonly IReadOnlyDictionary<string, ManualActionRow> _manualActionsByRunningNodeKey;
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
    private string _stationControlMessage = "Chain controls ready / Chain 操作就绪";
    private bool _startVisible = true;
    private bool _stopVisible;
    private bool _stepVisible;
    private bool _isStepping;
    private bool _modeRunning;
    private bool _manualFunctionsActive;
    private bool _manualFunctionRunning;
    private ManualUnitRow? _selectedManualUnit;
    private EtherCatTopologyNode? _selectedEtherCatNode;
    private string _modeRequestMessage = "Mode control ready / 模式控制就绪";
    private string _eventDecodeMessage = "Waiting for PublicEventList / 等待报警列表";

    public MainViewModel(HmiSettings settings)
    {
        _settings = settings;
        _autoInfo = settings.AutoInfoLines.ToDictionary(item => item.Index);
        _modeDisplays = settings.ModeControl.Modes.ToDictionary(mode => mode.Id);
        EndpointUrl = settings.EndpointUrl;
        StationId = settings.StationId;
        StationName = settings.StationName;
        ProductName = settings.Brand.ProductName;
        ProductSubtitle = settings.Brand.Subtitle;
        ProductMark = settings.Brand.Mark;
        EtherCatSlaves = new ObservableCollection<EtherCatSlaveRow>(
            settings.Fieldbus.Slaves.OrderBy(slave => slave.Index).Select(slave => new EtherCatSlaveRow(slave)));
        EtherCatTopology = BuildEtherCatTopology(settings, EtherCatSlaves);
        IoChannels = new ObservableCollection<IoChannelRow>(
            settings.Fieldbus.Channels
                .OrderBy(channel => channel.SlaveIndex)
                .ThenBy(channel => channel.Channel)
                .Select(channel => new IoChannelRow(channel)));
        StationDataItems = CreateDataRows(settings, "station-data");
        TypeDataItems = CreateDataRows(settings, "type-data");
        DeviceDataItems = CreateDataRows(settings, "device-data");
        OverviewCards = new ObservableCollection<OverviewCardRow>(
            settings.OverviewCards.Select(card => new OverviewCardRow(card)));
        _overviewCardsByNodeKey = OverviewCards.ToLookup(card => card.NodeKey, StringComparer.Ordinal);
        ManualUnits = CreateManualUnits(settings);
        _manualDeviceFields = ManualUnits
            .SelectMany(unit => unit.DeviceFields)
            .ToDictionary(field => field.Key, StringComparer.Ordinal);
        _manualActionsByReleaseNodeKey = ManualUnits
            .SelectMany(unit => unit.Actions)
            .ToDictionary(action => action.ReleaseNodeKey, StringComparer.Ordinal);
        _manualActionsByRunningNodeKey = ManualUnits
            .SelectMany(unit => unit.Actions)
            .ToDictionary(action => action.RunningNodeKey, StringComparer.Ordinal);
        SelectedSlaveIoChannels = [];
        SelectedDeviceDataItems = [];
        SelectedManualUnit = ManualUnits.Skip(1).FirstOrDefault() ?? ManualUnits.FirstOrDefault();
        SelectedEtherCatNode = EtherCatTopology.FirstOrDefault();
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

    public ObservableCollection<EtherCatTopologyNode> EtherCatTopology { get; }

    public ObservableCollection<IoChannelRow> IoChannels { get; }

    public ObservableCollection<IoChannelRow> SelectedSlaveIoChannels { get; }

    public ObservableCollection<ManualUnitRow> ManualUnits { get; }

    public ObservableCollection<DataValueRow> StationDataItems { get; }

    public ObservableCollection<DataValueRow> TypeDataItems { get; }

    public ObservableCollection<DataValueRow> DeviceDataItems { get; }

    public ObservableCollection<OverviewCardRow> OverviewCards { get; }

    public ObservableCollection<DataValueRow> SelectedDeviceDataItems { get; }

    public ObservableCollection<PublicEventRow> ActiveEvents { get; }

    public string StationId { get; }

    public string StationName { get; }

    public string EndpointUrl { get; }

    public string ProductName { get; }

    public string ProductSubtitle { get; }

    public string ProductMark { get; }

    public ManualUnitRow? SelectedManualUnit
    {
        get => _selectedManualUnit;
        set => SetProperty(ref _selectedManualUnit, value);
    }

    public EtherCatTopologyNode? SelectedEtherCatNode
    {
        get => _selectedEtherCatNode;
        set
        {
            if (SetProperty(ref _selectedEtherCatNode, value))
            {
                RefreshSelectedSlaveIo();
                RefreshSelectedDeviceData();
                RaisePropertyChanged(nameof(SelectedNodeHasDeviceData));
                RaisePropertyChanged(nameof(SelectedNodeScopeText));
            }
        }
    }

    public bool SelectedNodeHasDeviceData =>
        SelectedEtherCatNode?.Slave is { DeviceDataGroup.Length: > 0 };

    public string SelectedNodeScopeText => SelectedEtherCatNode switch
    {
        null => "No node selected / 未选择节点",
        { IsMaster: true } => "Entire EtherCAT network / 整条 EtherCAT 总线",
        { Slave.Role: "coupler" } => "Terminal branch / 端子分支",
        { Slave.Role: "module" } => "I/O module channels / I/O 模块通道",
        { Slave.Role: "device" } => "Device interface / 设备接口",
        _ => "Selected slave channels / 当前从站通道"
    };

    public bool IsConnected
    {
        get => _isConnected;
        private set
        {
            if (SetProperty(ref _isConnected, value))
            {
                RefreshDataQuality();
                RaisePropertyChanged(nameof(CanRequestMode));
                RefreshControlAvailability();
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
                RefreshControlAvailability();
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
        1 => "Events",
        2 => "I/O",
        3 => "Data",
        _ => "Overview"
    };

    public string WindowTitle => $"{_settings.Brand.WindowTitle} — {PageName}";

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

    public string StationControlMessage
    {
        get => _stationControlMessage;
        private set => SetProperty(ref _stationControlMessage, value);
    }

    public bool StartVisible
    {
        get => _startVisible;
        private set
        {
            if (SetProperty(ref _startVisible, value))
            {
                RaisePropertyChanged(nameof(CanStartChain));
            }
        }
    }

    public bool StopVisible
    {
        get => _stopVisible;
        private set
        {
            if (SetProperty(ref _stopVisible, value))
            {
                RaisePropertyChanged(nameof(CanStopChain));
            }
        }
    }

    public bool StepVisible
    {
        get => _stepVisible;
        private set
        {
            if (SetProperty(ref _stepVisible, value))
            {
                RaisePropertyChanged(nameof(CanToggleStepMode));
                RaisePropertyChanged(nameof(CanPulseStep));
            }
        }
    }

    public bool IsStepping
    {
        get => _isStepping;
        private set
        {
            if (SetProperty(ref _isStepping, value))
            {
                RaisePropertyChanged(nameof(StepModeText));
                RaisePropertyChanged(nameof(CanPulseStep));
            }
        }
    }

    public bool ModeRunning
    {
        get => _modeRunning;
        private set => SetProperty(ref _modeRunning, value);
    }

    public bool ManualFunctionsActive
    {
        get => _manualFunctionsActive;
        private set
        {
            if (SetProperty(ref _manualFunctionsActive, value))
            {
                RefreshManualFunctions();
            }
        }
    }

    public bool ManualFunctionRunning
    {
        get => _manualFunctionRunning;
        private set
        {
            if (SetProperty(ref _manualFunctionRunning, value))
            {
                RefreshManualFunctions();
            }
        }
    }

    public string ActiveChainName => _modeDisplays.TryGetValue((byte)ModeId, out var mode)
        ? mode.ActiveChain
        : "No active Chain / 无活动 Chain";

    public string StepModeText => IsStepping
        ? "STEP MODE ON / 步进已开启"
        : "CONTINUOUS / 连续运行";

    public bool CanStartChain =>
        CanUseStationControls &&
        ModeId is 1 or 4 or 5 &&
        StartVisible &&
        !IsRunning;

    public bool CanStopChain =>
        CanUseStationControls &&
        ModeId is 1 or 4 or 5 &&
        (StopVisible || IsRunning);

    public bool CanToggleStepMode =>
        CanUseStationControls &&
        ModeId == 1 &&
        StepVisible;

    public bool CanPulseStep =>
        CanToggleStepMode &&
        IsStepping &&
        IsRunning;

    public bool HasRealExtendedControl =>
        IsConnected &&
        !IsDemo &&
        ((_dataSource?.SupportsStationCommands == true) ||
         (_dataSource?.SupportsManualFunctions == true));

    private bool CanUseStationControls =>
        !IsDataUnavailable &&
        !IsBusy &&
        PanelActive &&
        ModeReleased &&
        _dataSource?.SupportsStationCommands == true;

    public bool CanRequestMode =>
        !IsDataUnavailable &&
        !IsBusy &&
        PanelActive &&
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
                RaisePropertyChanged(nameof(ActiveChainName));
                RefreshControlAvailability();
                RefreshManualFunctions();
            }
        }
    }

    public string ModeName => _modeDisplays.TryGetValue((byte)ModeId, out var mode)
        ? string.IsNullOrWhiteSpace(mode.Chinese)
            ? mode.English.ToUpperInvariant()
            : $"{mode.English.ToUpperInvariant()} / {mode.Chinese}"
        : "NO MODE / 无模式";

    public bool ModeReleased
    {
        get => _modeReleased;
        private set
        {
            if (SetProperty(ref _modeReleased, value))
            {
                RefreshControlAvailability();
            }
        }
    }

    public bool IsRunning
    {
        get => _isRunning;
        private set
        {
            if (SetProperty(ref _isRunning, value))
            {
                RaisePropertyChanged(nameof(RunStateText));
                RefreshControlAvailability();
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
        private set
        {
            if (SetProperty(ref _token, value))
            {
                RaisePropertyChanged(nameof(PanelActive));
                RaisePropertyChanged(nameof(CanRequestMode));
                RefreshControlAvailability();
            }
        }
    }

    public bool PanelActive =>
        Token == _settings.ModeControl.PanelToken ||
        Token == 255;

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
        private set
        {
            if (SetProperty(ref _busOk, value))
            {
                RefreshEtherCatMaster();
            }
        }
    }

    public bool StationIsEmpty
    {
        get => _stationIsEmpty;
        private set => SetProperty(ref _stationIsEmpty, value);
    }

    public bool MasterOk
    {
        get => _masterOk;
        private set
        {
            if (SetProperty(ref _masterOk, value))
            {
                RefreshEtherCatMaster();
            }
        }
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
                RefreshManualFunctions();
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
                RefreshManualFunctions();
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
                RefreshManualFunctions();
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
                RefreshManualFunctions();
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
                RefreshManualFunctions();
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
                RefreshManualFunctions();
            }
        }
    }

    public bool KistlerAvailable => IsStableUnitState(KistlerUnitState);

    public string KistlerState => DescribeUnitState(KistlerUnitState);

    public void SelectPage(int pageIndex)
    {
        if (pageIndex is < 0 or > 3)
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

    public async Task<ControlRequestResult> RequestStationCommandAsync(
        StationCommand command,
        CancellationToken cancellationToken)
    {
        if (_dataSource is null || !CanUseStationControls)
        {
            return new ControlRequestResult(
                false,
                "Chain control is unavailable. Use DEMO, or complete real pulse/handshake commissioning first.");
        }

        IsBusy = true;
        try
        {
            StationControlMessage = $"Requesting {command} / 正在请求 {command}";
            var result = await _dataSource.RequestStationCommandAsync(command, cancellationToken);
            StationControlMessage = result.Message;
            return result;
        }
        finally
        {
            IsBusy = false;
        }
    }

    public async Task<ControlRequestResult> SetManualFunctionAsync(
        ManualActionRow action,
        bool execute,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(action);
        if (_dataSource?.SupportsManualFunctions != true ||
            ModeId != 3 ||
            (execute && !action.CanExecute))
        {
            return new ControlRequestResult(
                false,
                "Manual function is display-only or its CpStudio release condition is not fulfilled.");
        }

        var result = await _dataSource.SetManualFunctionAsync(
            action.UnitKey,
            action.Key,
            execute,
            cancellationToken);
        StationControlMessage = result.Message;
        return result;
    }

    public async Task ConnectAsync(
        bool useDemo,
        string userName,
        string password,
        bool autoAcceptUntrustedCertificate,
        bool enableModeRequests,
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
                new ConnectionOptions(
                    userName,
                    password,
                    autoAcceptUntrustedCertificate,
                    enableModeRequests),
                cancellationToken);
            ModeRequestMessage = _dataSource.SupportsModeRequests
                ? "Mode requests enabled for this session / 本次会话已开放模式切换"
                : "Read-only session: mode requests disabled / 只读会话：模式切换未开放";
            StationControlMessage = _dataSource.SupportsStationCommands
                ? "Chain and manual controls enabled in DEMO / 演示模式已开放 Chain 与手动功能"
                : "Real Chain/manual writes locked pending commissioning / 真机 Chain 与手动写入尚未验收";
            RefreshControlAvailability();
            RefreshManualFunctions();
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

            if (_manualDeviceFields.TryGetValue(eventArgs.Key, out var deviceField))
            {
                deviceField.Update(eventArgs.Value, eventArgs.IsGood, eventArgs.Status);
            }

            foreach (var overviewCard in _overviewCardsByNodeKey[eventArgs.Key])
            {
                overviewCard.Update(eventArgs.Value, eventArgs.IsGood, eventArgs.Status);
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
            _liveValues[eventArgs.Key] = eventArgs.Value;
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
            case "ModeRunning": ModeRunning = ToBoolean(value); break;
            case "StartVisible": StartVisible = ToBoolean(value); break;
            case "StopVisible": StopVisible = ToBoolean(value); break;
            case "StepVisible": StepVisible = ToBoolean(value); break;
            case "IsStepping": IsStepping = ToBoolean(value); break;
            case "ManualFunctionsActive": ManualFunctionsActive = ToBoolean(value); break;
            case "ManualFunctionRunning": ManualFunctionRunning = ToBoolean(value); break;
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
            default:
                ApplyManualFunctionValue(key, value);
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
            ActiveEvents.Clear();
            EventDecodeMessage =
                "PublicEventList is subscribed, but this server payload needs one read-only browse/decode acceptance. / 已订阅报警列表，需一次只读联机确认结构解码。";
            RaisePropertyChanged(nameof(HasActiveEvents));
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

    private void ApplyManualFunctionValue(string key, object? value)
    {
        if (_manualActionsByReleaseNodeKey.ContainsKey(key))
        {
            _manualReleaseValues[key] = ToBoolean(value);
        }
        else if (_manualActionsByRunningNodeKey.ContainsKey(key))
        {
            _manualRunningValues[key] = ToBoolean(value);
        }

        RefreshManualFunctions();
    }

    private static ObservableCollection<EtherCatTopologyNode> BuildEtherCatTopology(
        HmiSettings settings,
        IReadOnlyCollection<EtherCatSlaveRow> slaves)
    {
        var root = new EtherCatTopologyNode(
            settings.Fieldbus.MasterDesignator,
            "EtherCAT Master / EtherCAT 主站",
            "ctrlX EtherCAT Master");
        var nodes = slaves.ToDictionary(
            slave => slave.Index,
            slave => new EtherCatTopologyNode(
                slave.Designator,
                slave.DisplayName,
                slave.DeviceType,
                slave));

        foreach (var slave in slaves.OrderBy(item => item.Index))
        {
            var node = nodes[slave.Index];
            if (slave.ParentIndex is int parentIndex && nodes.TryGetValue(parentIndex, out var parent))
            {
                parent.Children.Add(node);
            }
            else
            {
                root.Children.Add(node);
            }
        }

        return [root];
    }

    private static ObservableCollection<ManualUnitRow> CreateManualUnits(HmiSettings settings)
    {
        return new ObservableCollection<ManualUnitRow>(settings.ManualUnits.Select(unit =>
            new ManualUnitRow(
                unit.Key,
                unit.Designator,
                string.IsNullOrWhiteSpace(unit.Chinese)
                    ? unit.English
                    : $"{unit.English} / {unit.Chinese}",
                unit.Category,
                unit.StateNodeKey,
                unit.SecondaryStateNodeKey,
                unit.StateValueMap,
                unit.Actions.Select(action => new ManualActionRow(
                    unit.Key,
                    action.Key,
                    action.English,
                    action.Chinese,
                    action.Description,
                    action.ReleaseNodeKey,
                    action.RunningNodeKey)),
                unit.Fields.Select(field => new DeviceFieldRow(
                    field.NodeKey,
                    ParseDeviceFieldSection(field.Section),
                    field.English,
                    field.Chinese,
                    field.Unit,
                    field.IsBoolean,
                    field.ValueMap)))));
    }

    private static DeviceFieldSection ParseDeviceFieldSection(string section) => section switch
    {
        "parameter" => DeviceFieldSection.Parameter,
        "result" => DeviceFieldSection.Result,
        _ => DeviceFieldSection.Status
    };

    private void RefreshSelectedSlaveIo()
    {
        if (SelectedSlaveIoChannels is null)
        {
            return;
        }

        SelectedSlaveIoChannels.Clear();
        if (SelectedEtherCatNode is null)
        {
            return;
        }

        IEnumerable<IoChannelRow> selectedChannels = SelectedEtherCatNode switch
        {
            { IsMaster: true } => IoChannels,
            { Slave.Role: "coupler" } node => IoChannels.Where(
                channel => GetDescendantSlaveIndexes(node.Slave.Index).Contains(channel.SlaveIndex)),
            { Slave: not null } node => IoChannels.Where(channel => channel.SlaveIndex == node.Slave.Index),
            _ => []
        };
        foreach (var channel in selectedChannels)
        {
            SelectedSlaveIoChannels.Add(channel);
        }
    }

    private HashSet<int> GetDescendantSlaveIndexes(int parentIndex)
    {
        var result = new HashSet<int>();
        var pending = new Queue<int>();
        pending.Enqueue(parentIndex);
        while (pending.Count > 0)
        {
            var current = pending.Dequeue();
            foreach (var child in EtherCatSlaves.Where(slave => slave.ParentIndex == current))
            {
                if (result.Add(child.Index))
                {
                    pending.Enqueue(child.Index);
                }
            }
        }

        return result;
    }

    private void RefreshSelectedDeviceData()
    {
        SelectedDeviceDataItems.Clear();
        var group = SelectedEtherCatNode?.Slave?.DeviceDataGroup;
        if (string.IsNullOrWhiteSpace(group))
        {
            return;
        }

        var keys = _settings.Nodes
            .Where(node =>
                string.Equals(node.Category, "device-data", StringComparison.Ordinal) &&
                (string.Equals(node.Group, group, StringComparison.Ordinal) ||
                 node.Group.StartsWith($"{group} -", StringComparison.Ordinal)))
            .Select(node => node.Key)
            .ToHashSet(StringComparer.Ordinal);
        foreach (var row in DeviceDataItems.Where(row => keys.Contains(row.Key)))
        {
            SelectedDeviceDataItems.Add(row);
        }
    }

    private void RefreshEtherCatMaster()
    {
        EtherCatTopology.FirstOrDefault()?.SetMasterOperational(BusOk && MasterOk);
    }

    private void RefreshControlAvailability()
    {
        RaisePropertyChanged(nameof(CanStartChain));
        RaisePropertyChanged(nameof(CanStopChain));
        RaisePropertyChanged(nameof(CanToggleStepMode));
        RaisePropertyChanged(nameof(CanPulseStep));
        RaisePropertyChanged(nameof(HasRealExtendedControl));
        RefreshManualFunctions();
    }

    private void RefreshManualFunctions()
    {
        if (ManualUnits is null)
        {
            return;
        }

        var controlAvailable =
            !IsDataUnavailable &&
            ModeId == 3 &&
            ManualFunctionsActive &&
            !ManualFunctionRunning &&
            PanelActive &&
            _dataSource?.SupportsManualFunctions == true;
        foreach (var unit in ManualUnits)
        {
            if (string.IsNullOrWhiteSpace(unit.StateNodeKey))
            {
                unit.UpdateState("CONFIGURED / 已配置", true);
            }
            else if (!_liveValues.TryGetValue(unit.StateNodeKey, out var stateValue))
            {
                unit.UpdateState("NO DATA / 无数据", false);
            }
            else if (!string.IsNullOrWhiteSpace(unit.SecondaryStateNodeKey))
            {
                if (!_liveValues.TryGetValue(unit.SecondaryStateNodeKey, out var secondaryStateValue))
                {
                    unit.UpdateState("NO DATA / 无数据", false);
                    UpdateManualActions(unit, controlAvailable);
                    continue;
                }

                var primaryState = ToBoolean(stateValue);
                var secondaryState = ToBoolean(secondaryStateValue);
                var stateKey = $"{(primaryState ? 1 : 0)}{(secondaryState ? 1 : 0)}";
                var stateText = unit.StateValueMap.TryGetValue(stateKey, out var mappedState)
                    ? mappedState
                    : stateKey;
                unit.UpdateState(stateText, primaryState ^ secondaryState);
            }
            else if (stateValue is bool booleanState)
            {
                var stateKey = booleanState ? "True" : "False";
                var stateText = unit.StateValueMap.TryGetValue(stateKey, out var mappedState)
                    ? mappedState
                    : booleanState ? "TRUE / ON" : "FALSE / OFF";
                unit.UpdateState(stateText, true);
            }
            else
            {
                var state = ToInt32(stateValue);
                var stateKey = Convert.ToString(stateValue, CultureInfo.InvariantCulture) ?? string.Empty;
                var stateText = unit.StateValueMap.TryGetValue(stateKey, out var mappedState)
                    ? mappedState
                    : DescribeUnitState(state);
                unit.UpdateState(stateText, IsStableUnitState(state));
            }

            UpdateManualActions(unit, controlAvailable);
        }
    }

    private void UpdateManualActions(
        ManualUnitRow unit,
        bool controlAvailable)
    {
        foreach (var action in unit.Actions)
        {
            var released = _manualReleaseValues.TryGetValue(action.ReleaseNodeKey, out var releaseValue) &&
                releaseValue;
            var running = _manualRunningValues.TryGetValue(action.RunningNodeKey, out var runningValue) &&
                          runningValue;
            action.Update(released, running, controlAvailable);
        }
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
        RefreshEtherCatMaster();
        RefreshControlAvailability();
    }

    private void ResetLiveValues()
    {
        _badNodes.Clear();
        _manualReleaseValues.Clear();
        _manualRunningValues.Clear();
        _liveValues.Clear();
        _hasReceivedData = false;
        IsStale = false;
        ModeId = 0;
        ModeReleased = false;
        IsRunning = false;
        IsStopping = false;
        ModeRunning = false;
        StartVisible = true;
        StopVisible = false;
        StepVisible = false;
        IsStepping = false;
        ManualFunctionsActive = false;
        ManualFunctionRunning = false;
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

        foreach (var row in _manualDeviceFields.Values)
        {
            row.Reset();
        }

        foreach (var row in OverviewCards)
        {
            row.Reset();
        }

        ActiveEvents.Clear();
        EventDecodeMessage = "Waiting for PublicEventList / 等待报警列表";
        ModeRequestMessage = "Mode control ready / 模式控制就绪";
        StationControlMessage = "Chain controls ready / Chain 操作就绪";
        RaisePropertyChanged(nameof(HasActiveEvents));
        RefreshDerivedProperties();
    }

    private void RefreshDataQuality()
    {
        RaisePropertyChanged(nameof(IsDataUnavailable));
        RaisePropertyChanged(nameof(DataQualityText));
        RaisePropertyChanged(nameof(CanRequestMode));
        RefreshControlAvailability();
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
        RefreshManualFunctions();
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
