using System.Collections;
using System.Globalization;
using System.Reflection;
using Bpp.ResistantStation.Hmi.ViewModels;
using Opc.Ua;

namespace Bpp.ResistantStation.Hmi.Services;

internal static class PublicEventDecoder
{
    public static bool TryDecode(object? payload, out IReadOnlyList<PublicEventRow> rows)
    {
        var root = Unwrap(payload);
        var entries = ReadMember(root, "Entry") as IEnumerable;
        if (entries is null)
        {
            rows = [];
            return false;
        }

        var result = new List<PublicEventRow>();
        foreach (var entryValue in entries)
        {
            var entry = Unwrap(entryValue);
            var eventClass = ToUInt32(ReadMember(entry, "Class"));
            var clearedUtc = ToUtcDateTime(ReadMember(entry, "DtClear"));
            if (eventClass == 0 || clearedUtc > DateTime.UnixEpoch)
            {
                continue;
            }

            var number = ToInt32(ReadMember(entry, "Number"));
            var source = ToText(ReadMember(entry, "Source"));
            result.Add(new PublicEventRow
            {
                InstanceId = ToUInt32(ReadMember(entry, "InstanceId")),
                Number = number,
                Class = eventClass,
                Source = source,
                Text = string.IsNullOrWhiteSpace(source)
                    ? $"Event {number}"
                    : $"{source} · Event {number}",
                AdditionalInfo = ToText(ReadMember(entry, "AddText")).Replace("$T", " · "),
                Timestamp = ToLocalDateTime(ReadMember(entry, "DtEntry")),
                EntryOrder = ToUInt32(ReadMember(entry, "EntryOrder"))
            });
        }

        rows = result
            .OrderByDescending(row => row.Timestamp)
            .ThenByDescending(row => row.EntryOrder)
            .ToArray();
        return true;
    }

    private static object? Unwrap(object? value)
    {
        return value switch
        {
            Variant variant => Unwrap(variant.Value),
            ExtensionObject extension => Unwrap(extension.Body),
            DataValue dataValue => Unwrap(dataValue.Value),
            _ => value
        };
    }

    private static object? ReadMember(object? value, string name)
    {
        value = Unwrap(value);
        if (value is null)
        {
            return null;
        }

        if (value is IDictionary dictionary)
        {
            foreach (DictionaryEntry entry in dictionary)
            {
                if (string.Equals(entry.Key?.ToString(), name, StringComparison.OrdinalIgnoreCase))
                {
                    return Unwrap(entry.Value);
                }
            }
        }

        var flags = BindingFlags.Instance | BindingFlags.Public | BindingFlags.IgnoreCase;
        var type = value.GetType();
        return Unwrap(type.GetProperty(name, flags)?.GetValue(value) ??
            type.GetField(name, flags)?.GetValue(value));
    }

    private static string ToText(object? value) =>
        Convert.ToString(Unwrap(value), CultureInfo.InvariantCulture) ?? string.Empty;

    private static int ToInt32(object? value) => value is null
        ? 0
        : Convert.ToInt32(Unwrap(value), CultureInfo.InvariantCulture);

    private static uint ToUInt32(object? value) => value is null
        ? 0
        : Convert.ToUInt32(Unwrap(value), CultureInfo.InvariantCulture);

    private static DateTime ToUtcDateTime(object? value)
    {
        value = Unwrap(value);
        return value switch
        {
            DateTime { Kind: DateTimeKind.Utc } dateTime => dateTime,
            DateTime { Kind: DateTimeKind.Local } dateTime => dateTime.ToUniversalTime(),
            DateTime dateTime => DateTime.SpecifyKind(dateTime, DateTimeKind.Utc),
            DateTimeOffset offset => offset.UtcDateTime,
            _ => DateTime.MinValue
        };
    }

    private static DateTime ToLocalDateTime(object? value) =>
        ToUtcDateTime(value).ToLocalTime();
}
