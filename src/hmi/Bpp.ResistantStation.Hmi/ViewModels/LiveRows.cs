using System.Collections;
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
