using System.IO;
using System.Text.Json;

namespace Bpp.ResistantStation.Hmi.Configuration;

public sealed class HmiSettings
{
    public string StationId { get; init; } = "Station010";

    public string StationName { get; init; } = "Resistance test station";

    public string EndpointUrl { get; init; } = "opc.tcp://192.168.0.51:4840";

    public string NamespaceUri { get; init; } =
        "http://www.boschrexroth.com/OpcUa/Datalayer";

    public int PublishingIntervalMs { get; init; } = 250;

    public IReadOnlyList<HmiNodeDefinition> Nodes { get; init; } = [];

    public IReadOnlyList<LocalizedAutoInfo> AutoInfoLines { get; init; } = [];

    public static HmiSettings Load(string path)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(path);

        var json = File.ReadAllText(path);
        var settings = JsonSerializer.Deserialize<HmiSettings>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        if (settings is null || settings.Nodes.Count == 0)
        {
            throw new InvalidDataException("The read-only OPC UA node catalog is empty.");
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
            throw new InvalidDataException("The phase-one HMI catalog must remain read-only.");
        }

        return settings;
    }
}

public sealed class HmiNodeDefinition
{
    public string Key { get; init; } = string.Empty;

    public string Identifier { get; init; } = string.Empty;

    public string DataType { get; init; } = string.Empty;

    public string Category { get; init; } = string.Empty;

    public bool Enabled { get; init; } = true;

    public bool WriteAllowed { get; init; }
}

public sealed class LocalizedAutoInfo
{
    public int Index { get; init; }

    public string English { get; init; } = string.Empty;

    public string Chinese { get; init; } = string.Empty;
}
