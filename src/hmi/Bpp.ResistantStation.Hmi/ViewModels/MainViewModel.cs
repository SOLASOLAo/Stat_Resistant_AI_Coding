using System.Globalization;
using System.Windows;
using Bpp.ResistantStation.Hmi.Configuration;
using Bpp.ResistantStation.Hmi.Services;

namespace Bpp.ResistantStation.Hmi.ViewModels;

public sealed class MainViewModel : ObservableObject, IAsyncDisposable
{
    private readonly HmiSettings _settings;
    private readonly IReadOnlyDictionary<int, LocalizedAutoInfo> _autoInfo;
    private readonly HashSet<string> _badNodes = new(StringComparer.Ordinal);
    private IStationDataSource? _dataSource;
    private bool _isConnected;
    private bool _isBusy;
    private bool _isDemo;
    private bool _hasReceivedData;
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

    public MainViewModel(HmiSettings settings)
    {
        _settings = settings;
        _autoInfo = settings.AutoInfoLines.ToDictionary(item => item.Index);
        EndpointUrl = settings.EndpointUrl;
        StationId = settings.StationId;
        StationName = settings.StationName;
        RefreshDerivedProperties();
    }

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
            }
        }
    }

    public bool IsBusy
    {
        get => _isBusy;
        private set => SetProperty(ref _isBusy, value);
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

    public bool IsDataUnavailable => !IsConnected || !_hasReceivedData || _badNodes.Count > 0;

    public string DataQualityText => !IsConnected
        ? "PLC DATA OFFLINE / PLC 数据未连接"
        : !_hasReceivedData
            ? "WAITING FOR PLC DATA / 正在等待 PLC 数据"
            : _badNodes.Count > 0
                ? $"BAD DATA QUALITY: {string.Join(", ", _badNodes.Order())}"
                : "DATA CURRENT / 数据有效";

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
            RaisePropertyChanged(nameof(LastUpdateText));

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
            case "BusOk": BusOk = ToBoolean(value); break;
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
        }
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
        ModeId = 0;
        ModeReleased = false;
        IsRunning = false;
        IsStopping = false;
        ExecState = 0;
        Token = 0;
        AutoInfoIndex = 0;
        IsInHomePosition = false;
        BusOk = false;
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
        RefreshDerivedProperties();
    }

    private void RefreshDataQuality()
    {
        RaisePropertyChanged(nameof(IsDataUnavailable));
        RaisePropertyChanged(nameof(DataQualityText));
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
