using System.IO;
using System.Text.Json;

namespace Bpp.ResistantStation.Hmi.Configuration;

public sealed class HmiSettings
{
    private static readonly byte[] SupportedModes = [1, 3, 4, 5];

    public string StationId { get; init; } = "Station010";
    public string StationName { get; init; } = "Resistance test station";
    public string EndpointUrl { get; init; } = "opc.tcp://192.168.0.51:4840";
    public string NamespaceUri { get; init; } = "http://www.boschrexroth.com/OpcUa/Datalayer";
    public int PublishingIntervalMs { get; init; } = 250;
    public int StaleTimeoutMs { get; init; } = 3_000;
    public int ReconnectDelayMs { get; init; } = 3_000;
    public IReadOnlyList<HmiNodeDefinition> Nodes { get; init; } = [];
    public IReadOnlyList<LocalizedAutoInfo> AutoInfoLines { get; init; } = [];
    public ModeControlSettings ModeControl { get; init; } = new();
    public FieldbusSettings Fieldbus { get; init; } = new();

    public static HmiSettings Load(string path)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(path);
        var settings = JsonSerializer.Deserialize<HmiSettings>(
            File.ReadAllText(path),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        if (settings is null || settings.Nodes.Count == 0)
        {
            throw new InvalidDataException("The OPC UA node catalog is empty.");
        }

        if (!Uri.TryCreate(settings.EndpointUrl, UriKind.Absolute, out var endpoint) ||
            !string.Equals(endpoint.Scheme, "opc.tcp", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("EndpointUrl must be an absolute opc.tcp URL.");
        }

        if (!Uri.TryCreate(settings.NamespaceUri, UriKind.Absolute, out _))
        {
            throw new InvalidDataException("NamespaceUri must be an absolute URI.");
        }

        if (settings.Nodes.Any(node => node.WriteAllowed))
        {
            throw new InvalidDataException(
                "Subscription nodes are read-only. Mode writes belong to the semantic allowlist.");
        }

        if (settings.Nodes.Select(node => node.Key).Distinct(StringComparer.Ordinal).Count() !=
            settings.Nodes.Count)
        {
            throw new InvalidDataException("OPC UA node keys must be unique.");
        }

        settings.ModeControl.Validate(SupportedModes);
        return settings;
    }
}

public sealed class HmiNodeDefinition
{
    public string Key { get; init; } = string.Empty;
    public string Identifier { get; init; } = string.Empty;
    public string DataType { get; init; } = string.Empty;
    public string Category { get; init; } = string.Empty;
    public string Group { get; init; } = string.Empty;
    public string English { get; init; } = string.Empty;
    public string Chinese { get; init; } = string.Empty;
    public string Unit { get; init; } = string.Empty;
    public bool Legacy { get; init; }
    public bool Enabled { get; init; } = true;
    public bool WriteAllowed { get; init; }
}

public sealed class LocalizedAutoInfo
{
    public int Index { get; init; }
    public string English { get; init; } = string.Empty;
    public string Chinese { get; init; } = string.Empty;
}

public sealed class ModeControlSettings
{
    private const string AllowedTokenRequestIdentifier =
        "plc/app/Application/sym/Station/Extension/TokenRequest";
    private const string AllowedModeIdRequestIdentifier =
        "plc/app/Application/sym/Station/Extension/ModeIdRequest";

    public bool Enabled { get; init; } = true;
    public byte PanelToken { get; init; } = 1;
    public int RequestTimeoutMs { get; init; } = 5_000;
    public string TokenRequestIdentifier { get; init; } = AllowedTokenRequestIdentifier;
    public string ModeIdRequestIdentifier { get; init; } = AllowedModeIdRequestIdentifier;
    public IReadOnlyList<byte> AllowedModeIds { get; init; } = [1, 3, 4, 5];

    internal void Validate(IReadOnlyCollection<byte> supportedModes)
    {
        if (!Enabled)
        {
            return;
        }

        if (PanelToken is 0 or 255)
        {
            throw new InvalidDataException("PanelToken must identify one HMI panel (1..254).");
        }

        if (!string.Equals(
                TokenRequestIdentifier,
                AllowedTokenRequestIdentifier,
                StringComparison.Ordinal) ||
            !string.Equals(
                ModeIdRequestIdentifier,
                AllowedModeIdRequestIdentifier,
                StringComparison.Ordinal))
        {
            throw new InvalidDataException(
                "The mode-control allowlist may contain only TokenRequest and ModeIdRequest.");
        }

        if (AllowedModeIds.Count != supportedModes.Count ||
            AllowedModeIds.Except(supportedModes).Any())
        {
            throw new InvalidDataException("AllowedModeIds must be exactly 1, 3, 4 and 5.");
        }
    }
}

public sealed class FieldbusSettings
{
    public string MasterDesignator { get; init; } = "=000+S-A620-X1";
    public IReadOnlyList<FieldbusSlaveDefinition> Slaves { get; init; } = [];
    public IReadOnlyList<IoChannelDefinition> Channels { get; init; } = [];
}

public sealed class FieldbusSlaveDefinition
{
    public int Index { get; init; }
    public int? ParentIndex { get; init; }
    public string Designator { get; init; } = string.Empty;
    public string DeviceType { get; init; } = string.Empty;
    public string DisplayName { get; init; } = string.Empty;
    public string SourceTypeName { get; init; } = string.Empty;
}

public sealed class IoChannelDefinition
{
    public int SlaveIndex { get; init; }
    public int Channel { get; init; }
    public string Direction { get; init; } = string.Empty;
    public string Bmk { get; init; } = string.Empty;
    public string English { get; init; } = string.Empty;
    public string Chinese { get; init; } = string.Empty;
    public string NodeKey { get; init; } = string.Empty;
    public string WiringStatus { get; init; } = "wired";
}
