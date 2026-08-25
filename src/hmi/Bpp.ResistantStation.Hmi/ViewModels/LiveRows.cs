using System.Collections;
using System.Collections.ObjectModel;
using System.Globalization;
using Bpp.ResistantStation.Hmi.Configuration;

namespace Bpp.ResistantStation.Hmi.ViewModels;

public sealed class DataValueRow(HmiNodeDefinition definition) : ObservableObject
{
    private string _value = "—";
    private string _quality = "No data";

    public string Key { get; } = definition.Key;
    public string Group { get; } = definition.Group;
    public string English { get; } = definition.English;
    public string Chinese { get; } = definition.Chinese;
    public string Label => string.IsNullOrWhiteSpace(Chinese) ? English : $"{Chinese} / {English}";
    public string Unit { get; } = definition.Unit;
    public bool IsLegacy { get; } = definition.Legacy;

    public string Value
    {
        get => _value;
        private set => SetProperty(ref _value, value);
    }

    public string Quality
    {
        get => _quality;
        private set => SetProperty(ref _quality, value);
    }

    public void Update(object? value, bool isGood, string status)
    {
        Value = Format(value);
        Quality = isGood ? "Good" : status;
    }

    public void Reset()
    {
        Value = "—";
        Quality = "No data";
    }

    private static string Format(object? value)
    {
        if (value is null)
        {
            return "—";
        }

        if (value is bool boolean)
        {
            return boolean ? "TRUE" : "FALSE";
        }

        if (value is string text)
        {
            return string.IsNullOrEmpty(text) ? "(empty)" : text;
        }

        if (value is IEnumerable values and not byte[])
        {
            var formatted = values.Cast<object?>()
                .Select(item => Convert.ToString(item, CultureInfo.InvariantCulture) ?? "—");
            return $"[{string.Join(", ", formatted)}]";
        }

        return Convert.ToString(value, CultureInfo.InvariantCulture) ?? "—";
    }
}

public sealed class IoChannelRow(IoChannelDefinition definition) : ObservableObject
{
    private bool? _value;
    private string _quality = "No data";

    public int SlaveIndex { get; } = definition.SlaveIndex;
    public int Channel { get; } = definition.Channel;
    public string Direction { get; } = definition.Direction;
    public string Bmk { get; } = definition.Bmk;
    public string NodeKey { get; } = definition.NodeKey;
    public string WiringStatus { get; } = definition.WiringStatus;
    public string Description { get; } = string.IsNullOrWhiteSpace(definition.Chinese)
        ? definition.English
        : $"{definition.Chinese} / {definition.English}";

    public bool? Value
    {
        get => _value;
        private set
        {
            if (SetProperty(ref _value, value))
            {
                RaisePropertyChanged(nameof(ValueText));
            }
        }
    }

    public string ValueText => Value switch
    {
        true => "TRUE / 1",
        false => "FALSE / 0",
        _ => "N/A"
    };

    public string Quality
    {
        get => _quality;
        private set => SetProperty(ref _quality, value);
    }

    public void Update(object? value, bool isGood, string status)
    {
        Value = isGood ? Convert.ToBoolean(value, CultureInfo.InvariantCulture) : null;
        Quality = isGood ? "Good" : status;
    }

    public void Reset()
    {
        Value = null;
        Quality = "No data";
    }
}

public sealed class EtherCatSlaveRow(FieldbusSlaveDefinition definition) : ObservableObject
{
    private int _address;
    private int _deviceState;
    private int _linkState;
    private bool _workingCounterInvalid = true;
    private uint _workingCounterErrors;

    public int Index { get; } = definition.Index;
    public int? ParentIndex { get; } = definition.ParentIndex;
    public string Designator { get; } = definition.Designator;
    public string DeviceType { get; } = definition.DeviceType;
    public string DisplayName { get; } = string.IsNullOrWhiteSpace(definition.DisplayName)
        ? definition.DeviceType
        : definition.DisplayName;
    public string SourceTypeName { get; } = definition.SourceTypeName;

    public int Address
    {
        get => _address;
        set => SetProperty(ref _address, value);
    }

    public int DeviceState
    {
        get => _deviceState;
        set
        {
            if (SetProperty(ref _deviceState, value))
            {
                RaisePropertyChanged(nameof(StateText));
                RaisePropertyChanged(nameof(ProcessDataText));
                RaisePropertyChanged(nameof(IsOperational));
            }
        }
    }

    public int LinkState
    {
        get => _linkState;
        set
        {
            if (SetProperty(ref _linkState, value))
            {
                RaisePropertyChanged(nameof(LinkText));
            }
        }
    }

    public bool WorkingCounterInvalid
    {
        get => _workingCounterInvalid;
        set
        {
            if (SetProperty(ref _workingCounterInvalid, value))
            {
                RaisePropertyChanged(nameof(ProcessDataText));
                RaisePropertyChanged(nameof(IsOperational));
            }
        }
    }

    public uint WorkingCounterErrors
    {
        get => _workingCounterErrors;
        set => SetProperty(ref _workingCounterErrors, value);
    }

    public string StateText => DeviceState switch
    {
        0x01 => "INIT",
        0x02 => "PREOP",
        0x03 => "BOOTSTRAP",
        0x04 => "SAFEOP",
        0x08 => "OP",
        0 => "NO DATA",
        _ => $"0x{DeviceState:X2}"
    };

    public string LinkText => $"0x{LinkState:X2}";
    public string ProcessDataText => DeviceState == 0
        ? "NO DATA"
        : WorkingCounterInvalid
            ? "INVALID"
            : "VALID";
    public bool IsOperational => DeviceState == 0x08 && !WorkingCounterInvalid;

    public void Reset()
    {
        Address = 0;
        DeviceState = 0;
        LinkState = 0;
        WorkingCounterInvalid = true;
        WorkingCounterErrors = 0;
    }
}

public sealed class EtherCatTopologyNode : ObservableObject
{
    private bool _masterOperational;

    public EtherCatTopologyNode(
        string designator,
        string displayName,
        string deviceType,
        EtherCatSlaveRow? slave = null)
    {
        Designator = designator;
        DisplayName = displayName;
        DeviceType = deviceType;
        Slave = slave;
        if (slave is not null)
        {
            slave.PropertyChanged += (_, _) =>
            {
                RaisePropertyChanged(nameof(IsOperational));
                RaisePropertyChanged(nameof(StateText));
                RaisePropertyChanged(nameof(AddressText));
                RaisePropertyChanged(nameof(ProcessDataText));
                RaisePropertyChanged(nameof(WorkingCounterErrors));
            };
        }
    }

    public string Designator { get; }

    public string DisplayName { get; }

    public string DeviceType { get; }

    public EtherCatSlaveRow? Slave { get; }

    public ObservableCollection<EtherCatTopologyNode> Children { get; } = [];

    public bool IsMaster => Slave is null;

    public bool IsOperational => Slave?.IsOperational ?? _masterOperational;

    public string StateText => Slave?.StateText ?? (_masterOperational ? "OP" : "NOT READY");

    public string AddressText => Slave is null || Slave.Address == 0 ? "—" : Slave.Address.ToString(CultureInfo.InvariantCulture);

    public string ProcessDataText => Slave?.ProcessDataText ?? (_masterOperational ? "VALID" : "INVALID");

    public uint WorkingCounterErrors => Slave?.WorkingCounterErrors ?? 0;

    public void SetMasterOperational(bool value)
    {
        if (_masterOperational == value)
        {
            return;
        }

        _masterOperational = value;
        RaisePropertyChanged(nameof(IsOperational));
        RaisePropertyChanged(nameof(StateText));
        RaisePropertyChanged(nameof(ProcessDataText));
    }
}

public sealed class ManualUnitRow : ObservableObject
{
    private string _stateText = "NO DATA / 无数据";
    private bool _available;

    public ManualUnitRow(
        string key,
        string designator,
        string displayName,
        string category,
        IEnumerable<ManualActionRow> actions,
        IEnumerable<DeviceFieldRow>? deviceFields = null)
    {
        Key = key;
        Designator = designator;
        DisplayName = displayName;
        Category = category;
        Actions = new ObservableCollection<ManualActionRow>(actions);
        DeviceFields = new ObservableCollection<DeviceFieldRow>(deviceFields ?? []);
        Parameters = new ObservableCollection<DeviceFieldRow>(
            DeviceFields.Where(field => field.Section == DeviceFieldSection.Parameter));
        Statuses = new ObservableCollection<DeviceFieldRow>(
            DeviceFields.Where(field => field.Section == DeviceFieldSection.Status));
        Results = new ObservableCollection<DeviceFieldRow>(
            DeviceFields.Where(field => field.Section == DeviceFieldSection.Result));
    }

    public string Key { get; }

    public string Designator { get; }

    public string DisplayName { get; }

    public string Category { get; }

    public ObservableCollection<ManualActionRow> Actions { get; }

    public ObservableCollection<DeviceFieldRow> DeviceFields { get; }

    public ObservableCollection<DeviceFieldRow> Parameters { get; }

    public ObservableCollection<DeviceFieldRow> Statuses { get; }

    public ObservableCollection<DeviceFieldRow> Results { get; }

    public bool HasDeviceDetails => DeviceFields.Count > 0;

    public string StateText
    {
        get => _stateText;
        private set => SetProperty(ref _stateText, value);
    }

    public bool Available
    {
        get => _available;
        private set => SetProperty(ref _available, value);
    }

    public void UpdateState(string stateText, bool available)
    {
        StateText = stateText;
        Available = available;
    }
}

public enum DeviceFieldSection
{
    Parameter,
    Status,
    Result
}

public sealed class DeviceFieldRow(
    string key,
    DeviceFieldSection section,
    string english,
    string chinese,
    string unit = "",
    bool isBoolean = false) : ObservableObject
{
    private string _valueText = "—";
    private string _quality = "No data";
    private bool _isTrue;

    public string Key { get; } = key;

    public DeviceFieldSection Section { get; } = section;

    public string English { get; } = english;

    public string Chinese { get; } = chinese;

    public string Label => string.IsNullOrWhiteSpace(Chinese)
        ? English
        : $"{English} / {Chinese}";

    public string Unit { get; } = unit;

    public bool IsBoolean { get; } = isBoolean;

    public bool IsInput => Section == DeviceFieldSection.Parameter;

    public string ValueText
    {
        get => _valueText;
        private set => SetProperty(ref _valueText, value);
    }

    public string Quality
    {
        get => _quality;
        private set => SetProperty(ref _quality, value);
    }

    public bool IsTrue
    {
        get => _isTrue;
        private set => SetProperty(ref _isTrue, value);
    }

    public void Update(object? value, bool isGood, string status)
    {
        Quality = isGood ? "Good" : status;
        if (!isGood || value is null)
        {
            ValueText = "—";
            IsTrue = false;
            return;
        }

        if (IsBoolean)
        {
            IsTrue = Convert.ToBoolean(value, CultureInfo.InvariantCulture);
            ValueText = IsTrue ? "TRUE / ON" : "FALSE / OFF";
            return;
        }

        ValueText = Key switch
        {
            "BursterUpperRange" or "BursterLowerRange" => DescribeBursterRange(value),
            "KistlerMeasuringTimeout" => DescribeDuration(value),
            _ => Convert.ToString(value, CultureInfo.InvariantCulture) ?? "—"
        };
    }

    public void Reset()
    {
        ValueText = "—";
        Quality = "No data";
        IsTrue = false;
    }

    private static string DescribeBursterRange(object value)
    {
        var index = Convert.ToInt32(value, CultureInfo.InvariantCulture);
        return index switch
        {
            0 => "2 mΩ",
            1 => "20 mΩ",
            2 => "200 mΩ",
            3 => "2 Ω",
            4 => "20 Ω",
            5 => "200 Ω",
            6 => "2 kΩ",
            7 => "20 kΩ",
            8 => "200 kΩ",
            _ => $"UNKNOWN ({index})"
        };
    }

    private static string DescribeDuration(object value)
    {
        if (value is TimeSpan duration)
        {
            return $"{duration.TotalMilliseconds:0} ms";
        }

        if (value is IConvertible)
        {
            return $"{Convert.ToDouble(value, CultureInfo.InvariantCulture):0} ms";
        }

        return Convert.ToString(value, CultureInfo.InvariantCulture) ?? "—";
    }
}

public sealed class ManualActionRow(
    string unitKey,
    string key,
    string english,
    string chinese,
    string description) : ObservableObject
{
    private bool _released;
    private bool _running;
    private bool _controlAvailable;

    public string UnitKey { get; } = unitKey;

    public string Key { get; } = key;

    public string English { get; } = english;

    public string Chinese { get; } = chinese;

    public string Label => $"{Chinese} / {English}";

    public string Description { get; } = description;

    public bool Released
    {
        get => _released;
        private set
        {
            if (SetProperty(ref _released, value))
            {
                RaisePropertyChanged(nameof(CanExecute));
                RaisePropertyChanged(nameof(StatusText));
            }
        }
    }

    public bool Running
    {
        get => _running;
        private set
        {
            if (SetProperty(ref _running, value))
            {
                RaisePropertyChanged(nameof(StatusText));
            }
        }
    }

    public bool ControlAvailable
    {
        get => _controlAvailable;
        private set
        {
            if (SetProperty(ref _controlAvailable, value))
            {
                RaisePropertyChanged(nameof(CanExecute));
                RaisePropertyChanged(nameof(StatusText));
            }
        }
    }

    public bool CanExecute => Released && ControlAvailable;

    public string StatusText => Running
        ? "RUNNING / 执行中"
        : !Released
            ? "INTERLOCKED / 联锁未释放"
            : ControlAvailable
                ? "READY / 可执行"
                : "DISPLAY ONLY / 仅显示";

    public void Update(bool released, bool running, bool controlAvailable)
    {
        Released = released;
        Running = running;
        ControlAvailable = controlAvailable;
    }
}

public sealed class PublicEventRow : ObservableObject
{
    public uint InstanceId { get; init; }
    public int Number { get; init; }
    public uint Class { get; init; }
    public string Source { get; init; } = string.Empty;
    public string Text { get; init; } = string.Empty;
    public string AdditionalInfo { get; init; } = string.Empty;
    public DateTime Timestamp { get; init; }
    public uint EntryOrder { get; init; }

    public string ClassText => Class switch
    {
        1 => "INFO",
        2 => "WARNING",
        3 => "ERROR",
        4 => "SOFT ERROR",
        _ => "EMPTY"
    };
}
