using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Bpp.ResistantStation.Hmi.Configuration;

public sealed class HmiSettings
{
    public const int CurrentSchemaVersion = 2;
    private static readonly byte[] SupportedModes = [1, 3, 4, 5];

    public int SchemaVersion { get; init; }
    public BrandSettings Brand { get; init; } = new();
    public string StationId { get; init; } = string.Empty;
    public string StationName { get; init; } = string.Empty;
    public string EndpointUrl { get; init; } = string.Empty;
    public string NamespaceUri { get; init; } = string.Empty;
    public int PublishingIntervalMs { get; init; } = 250;
    public int StaleTimeoutMs { get; init; } = 3_000;
    public int ReconnectDelayMs { get; init; } = 3_000;
    public IReadOnlyList<HmiNodeDefinition> Nodes { get; init; } = [];
    public IReadOnlyList<LocalizedAutoInfo> AutoInfoLines { get; init; } = [];
    public IReadOnlyList<OverviewCardDefinition> OverviewCards { get; init; } = [];
    public IReadOnlyList<ManualUnitDefinition> ManualUnits { get; init; } = [];
    public ModeControlSettings ModeControl { get; init; } = new();
    public FieldbusSettings Fieldbus { get; init; } = new();

    public static HmiSettings Load(string path)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(path);
        var fullPath = Path.GetFullPath(path);
        if (!File.Exists(fullPath))
        {
            throw new FileNotFoundException("The HMI configuration file was not found.", fullPath);
        }

        var settings = JsonSerializer.Deserialize<HmiSettings>(
            File.ReadAllText(fullPath),
            new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true,
                UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow
            }) ??
            throw new InvalidDataException("The HMI configuration is empty.");
        settings.Validate();
        return settings;
    }

    private void Validate()
    {
        if (SchemaVersion != CurrentSchemaVersion)
        {
            throw new InvalidDataException(
                $"Unsupported HMI schemaVersion {SchemaVersion}; expected {CurrentSchemaVersion}.");
        }

        Brand.Validate();
        RequireText(StationId, nameof(StationId));
        RequireText(StationName, nameof(StationName));
        if (Nodes.Count == 0)
        {
            throw new InvalidDataException("The OPC UA node catalog is empty.");
        }

        if (!Uri.TryCreate(EndpointUrl, UriKind.Absolute, out var endpoint) ||
            !string.Equals(endpoint.Scheme, "opc.tcp", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("EndpointUrl must be an absolute opc.tcp URL.");
        }

        if (!Uri.TryCreate(NamespaceUri, UriKind.Absolute, out _))
        {
            throw new InvalidDataException("NamespaceUri must be an absolute URI.");
        }

        if (PublishingIntervalMs < 50 || StaleTimeoutMs < PublishingIntervalMs)
        {
            throw new InvalidDataException(
                "PublishingIntervalMs must be at least 50 ms and StaleTimeoutMs must not be shorter.");
        }

        if (Nodes.Any(node => node.WriteAllowed))
        {
            throw new InvalidDataException(
                "Subscription nodes are read-only. Mode writes belong to the semantic allowlist.");
        }

        foreach (var node in Nodes)
        {
            RequireText(node.Key, "Nodes[].Key");
            RequireText(node.Identifier, $"Nodes[{node.Key}].Identifier");
        }

        if (Nodes.Select(node => node.Key).Distinct(StringComparer.Ordinal).Count() != Nodes.Count)
        {
            throw new InvalidDataException("OPC UA node keys must be unique.");
        }

        var nodeKeys = Nodes.Select(node => node.Key).ToHashSet(StringComparer.Ordinal);
        ValidateUnique(AutoInfoLines.Select(line => line.Index), "AutoInfoLines indexes");
        ValidateUnique(OverviewCards.Select(card => card.Key), "OverviewCards keys");
        foreach (var card in OverviewCards)
        {
            RequireText(card.Key, "OverviewCards[].Key");
            RequireNode(nodeKeys, card.NodeKey, $"OverviewCards[{card.Key}].NodeKey");
        }

        ValidateUnique(ManualUnits.Select(unit => unit.Key), "ManualUnits keys");
        foreach (var unit in ManualUnits)
        {
            unit.Validate(nodeKeys);
        }
        ValidateUnique(
            ManualUnits.SelectMany(unit => unit.Actions).Select(action => action.ReleaseNodeKey),
            "Manual action release node keys");
        ValidateUnique(
            ManualUnits.SelectMany(unit => unit.Actions).Select(action => action.RunningNodeKey),
            "Manual action running node keys");
        ValidateUnique(
            ManualUnits.SelectMany(unit => unit.Fields).Select(field => field.NodeKey),
            "Manual Unit field node keys");

        Fieldbus.Validate(nodeKeys);
        ModeControl.Validate(SupportedModes, nodeKeys);
    }

    internal static void RequireNode(
        IReadOnlySet<string> nodeKeys,
        string key,
        string propertyName,
        bool optional = false)
    {
        if (optional && string.IsNullOrWhiteSpace(key))
        {
            return;
        }

        RequireText(key, propertyName);
        if (!nodeKeys.Contains(key))
        {
            throw new InvalidDataException($"{propertyName} references unknown node key '{key}'.");
        }
    }

    internal static void RequireText(string value, string propertyName)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidDataException($"{propertyName} must not be empty.");
        }
    }

    internal static void ValidateUnique<T>(IEnumerable<T> values, string label)
        where T : notnull
    {
        var items = values.ToArray();
        if (items.Distinct().Count() != items.Length)
        {
            throw new InvalidDataException($"{label} must be unique.");
        }
    }
}

public sealed class BrandSettings
{
    public string ProductName { get; init; } = "Automation HMI";
    public string Subtitle { get; init; } = "Configuration-driven operator interface";
    public string WindowTitle { get; init; } = "Automation HMI";
    public string Mark { get; init; } = "H";

    internal void Validate()
    {
        HmiSettings.RequireText(ProductName, "Brand.ProductName");
        HmiSettings.RequireText(WindowTitle, "Brand.WindowTitle");
        HmiSettings.RequireText(Mark, "Brand.Mark");
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

public sealed class OverviewCardDefinition
{
    public string Key { get; init; } = string.Empty;
    public string NodeKey { get; init; } = string.Empty;
    public string English { get; init; } = string.Empty;
    public string Chinese { get; init; } = string.Empty;
    public string Unit { get; init; } = string.Empty;
    public bool IsBoolean { get; init; }
    public IReadOnlyDictionary<string, string> ValueMap { get; init; } =
        new Dictionary<string, string>(StringComparer.Ordinal);
}

public sealed class ManualUnitDefinition
{
    public string Key { get; init; } = string.Empty;
    public string Designator { get; init; } = string.Empty;
    public string English { get; init; } = string.Empty;
    public string Chinese { get; init; } = string.Empty;
    public string Category { get; init; } = string.Empty;
    public string StateNodeKey { get; init; } = string.Empty;
    public string SecondaryStateNodeKey { get; init; } = string.Empty;
    public IReadOnlyDictionary<string, string> StateValueMap { get; init; } =
        new Dictionary<string, string>(StringComparer.Ordinal);
    public IReadOnlyList<ManualActionDefinition> Actions { get; init; } = [];
    public IReadOnlyList<DeviceFieldDefinition> Fields { get; init; } = [];

    internal void Validate(IReadOnlySet<string> nodeKeys)
    {
        HmiSettings.RequireText(Key, "ManualUnits[].Key");
        HmiSettings.RequireText(English, $"ManualUnits[{Key}].English");
        HmiSettings.RequireNode(nodeKeys, StateNodeKey, $"ManualUnits[{Key}].StateNodeKey", optional: true);
        HmiSettings.RequireNode(
            nodeKeys,
            SecondaryStateNodeKey,
            $"ManualUnits[{Key}].SecondaryStateNodeKey",
            optional: true);
        if (!string.IsNullOrWhiteSpace(SecondaryStateNodeKey) &&
            string.IsNullOrWhiteSpace(StateNodeKey))
        {
            throw new InvalidDataException(
                $"ManualUnits[{Key}].StateNodeKey is required when SecondaryStateNodeKey is configured.");
        }

        HmiSettings.ValidateUnique(Actions.Select(action => action.Key), $"ManualUnits[{Key}].Actions keys");
        foreach (var action in Actions)
        {
            action.Validate(Key, nodeKeys);
        }

        HmiSettings.ValidateUnique(Fields.Select(field => field.NodeKey), $"ManualUnits[{Key}].Fields node keys");
        foreach (var field in Fields)
        {
            field.Validate(Key, nodeKeys);
        }
    }
}

public sealed class ManualActionDefinition
{
    public string Key { get; init; } = string.Empty;
    public string English { get; init; } = string.Empty;
    public string Chinese { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public string ReleaseNodeKey { get; init; } = string.Empty;
    public string RunningNodeKey { get; init; } = string.Empty;

    internal void Validate(string unitKey, IReadOnlySet<string> nodeKeys)
    {
        HmiSettings.RequireText(Key, $"ManualUnits[{unitKey}].Actions[].Key");
        HmiSettings.RequireNode(nodeKeys, ReleaseNodeKey, $"ManualUnits[{unitKey}].Actions[{Key}].ReleaseNodeKey");
        HmiSettings.RequireNode(nodeKeys, RunningNodeKey, $"ManualUnits[{unitKey}].Actions[{Key}].RunningNodeKey");
    }
}

public sealed class DeviceFieldDefinition
{
    public string NodeKey { get; init; } = string.Empty;
    public string Section { get; init; } = "status";
    public string English { get; init; } = string.Empty;
    public string Chinese { get; init; } = string.Empty;
    public string Unit { get; init; } = string.Empty;
    public bool IsBoolean { get; init; }
    public IReadOnlyDictionary<string, string> ValueMap { get; init; } =
        new Dictionary<string, string>(StringComparer.Ordinal);

    internal void Validate(string unitKey, IReadOnlySet<string> nodeKeys)
    {
        HmiSettings.RequireNode(nodeKeys, NodeKey, $"ManualUnits[{unitKey}].Fields[].NodeKey");
        if (Section is not ("parameter" or "status" or "result"))
        {
            throw new InvalidDataException(
                $"ManualUnits[{unitKey}].Fields[{NodeKey}].Section must be parameter, status or result.");
        }
    }
}

public sealed class ModeControlSettings
{
    private const string AllowedTokenRequestIdentifier =
        "plc/app/Application/sym/Station/Extension/TokenRequest";
    private const string AllowedModeIdRequestIdentifier =
        "plc/app/Application/sym/Station/Extension/ModeIdRequest";

    public bool Enabled { get; init; }
    public byte PanelToken { get; init; } = 1;
    public int RequestTimeoutMs { get; init; } = 5_000;
    public string TokenRequestIdentifier { get; init; } = AllowedTokenRequestIdentifier;
    public string ModeIdRequestIdentifier { get; init; } = AllowedModeIdRequestIdentifier;
    public IReadOnlyList<byte> AllowedModeIds { get; init; } = [1, 3, 4, 5];
    public IReadOnlyList<ModeDisplayDefinition> Modes { get; init; } = [];
    public IReadOnlyList<string> SafetyPrerequisiteNodeKeys { get; init; } = [];
    public string ChangeoverPrerequisiteNodeKey { get; init; } = string.Empty;

    internal void Validate(
        IReadOnlyCollection<byte> supportedModes,
        IReadOnlySet<string> nodeKeys)
    {
        if (AllowedModeIds.Count != supportedModes.Count || AllowedModeIds.Except(supportedModes).Any())
        {
            throw new InvalidDataException("AllowedModeIds must be exactly 1, 3, 4 and 5.");
        }

        HmiSettings.ValidateUnique(Modes.Select(mode => mode.Id), "ModeControl.Modes IDs");
        if (Modes.Count != supportedModes.Count || Modes.Any(mode => !supportedModes.Contains(mode.Id)))
        {
            throw new InvalidDataException("ModeControl.Modes must define IDs 1, 3, 4 and 5.");
        }

        foreach (var mode in Modes)
        {
            HmiSettings.RequireText(mode.English, $"ModeControl.Modes[{mode.Id}].English");
            HmiSettings.RequireText(mode.ActiveChain, $"ModeControl.Modes[{mode.Id}].ActiveChain");
        }

        if (PanelToken is 0 or 255)
        {
            throw new InvalidDataException("PanelToken must identify one HMI panel (1..254).");
        }

        if (RequestTimeoutMs is < 250 or > 60_000)
        {
            throw new InvalidDataException("RequestTimeoutMs must be between 250 and 60000 ms.");
        }

        if (!string.Equals(TokenRequestIdentifier, AllowedTokenRequestIdentifier, StringComparison.Ordinal) ||
            !string.Equals(ModeIdRequestIdentifier, AllowedModeIdRequestIdentifier, StringComparison.Ordinal))
        {
            throw new InvalidDataException(
                "The mode-control allowlist may contain only TokenRequest and ModeIdRequest.");
        }

        if (!Enabled)
        {
            return;
        }

        HmiSettings.ValidateUnique(SafetyPrerequisiteNodeKeys, "ModeControl.SafetyPrerequisiteNodeKeys");
        foreach (var key in SafetyPrerequisiteNodeKeys)
        {
            HmiSettings.RequireNode(nodeKeys, key, "ModeControl.SafetyPrerequisiteNodeKeys[]");
        }

        HmiSettings.RequireNode(
            nodeKeys,
            ChangeoverPrerequisiteNodeKey,
            "ModeControl.ChangeoverPrerequisiteNodeKey",
            optional: true);
    }
}

public sealed class ModeDisplayDefinition
{
    public byte Id { get; init; }
    public string English { get; init; } = string.Empty;
    public string Chinese { get; init; } = string.Empty;
    public string ActiveChain { get; init; } = string.Empty;
}

public sealed class FieldbusSettings
{
    public string MasterDesignator { get; init; } = string.Empty;
    public IReadOnlyList<FieldbusSlaveDefinition> Slaves { get; init; } = [];
    public IReadOnlyList<IoChannelDefinition> Channels { get; init; } = [];

    internal void Validate(IReadOnlySet<string> nodeKeys)
    {
        HmiSettings.RequireText(MasterDesignator, "Fieldbus.MasterDesignator");
        HmiSettings.ValidateUnique(Slaves.Select(slave => slave.Index), "Fieldbus slave indexes");
        var slaveIndexes = Slaves.Select(slave => slave.Index).ToHashSet();
        var expectedIndexes = Enumerable.Range(1, Slaves.Count);
        if (!Slaves.Select(slave => slave.Index).Order().SequenceEqual(expectedIndexes))
        {
            throw new InvalidDataException(
                "Fieldbus slave indexes must be contiguous and start at 1.");
        }

        foreach (var slave in Slaves)
        {
            if (slave.Index <= 0 || (slave.ParentIndex is int parent && !slaveIndexes.Contains(parent)))
            {
                throw new InvalidDataException($"Fieldbus slave {slave.Index} has an invalid index or parent.");
            }

            if (slave.Role is not ("coupler" or "module" or "device"))
            {
                throw new InvalidDataException(
                    $"Fieldbus slave {slave.Index} role must be coupler, module or device.");
            }
        }

        var parentByIndex = Slaves.ToDictionary(slave => slave.Index, slave => slave.ParentIndex);
        foreach (var slave in Slaves)
        {
            var visited = new HashSet<int>();
            var current = slave.Index;
            while (parentByIndex[current] is int parent)
            {
                if (!visited.Add(current))
                {
                    throw new InvalidDataException(
                        $"Fieldbus slave {slave.Index} belongs to a cyclic parent chain.");
                }

                current = parent;
            }
        }

        HmiSettings.ValidateUnique(
            Channels.Select(channel => channel.NodeKey),
            "Fieldbus channel node keys");

        foreach (var channel in Channels)
        {
            if (!slaveIndexes.Contains(channel.SlaveIndex))
            {
                throw new InvalidDataException(
                    $"Fieldbus channel references unknown slave {channel.SlaveIndex}.");
            }

            HmiSettings.RequireNode(nodeKeys, channel.NodeKey, "Fieldbus.Channels[].NodeKey");
        }
    }
}

public sealed class FieldbusSlaveDefinition
{
    public int Index { get; init; }
    public int? ParentIndex { get; init; }
    public string Designator { get; init; } = string.Empty;
    public string DeviceType { get; init; } = string.Empty;
    public string DisplayName { get; init; } = string.Empty;
    public string SourceTypeName { get; init; } = string.Empty;
    public string Role { get; init; } = "device";
    public string DeviceDataGroup { get; init; } = string.Empty;
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
