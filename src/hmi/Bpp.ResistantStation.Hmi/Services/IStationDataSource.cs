namespace Bpp.ResistantStation.Hmi.Services;

public interface IStationDataSource : IAsyncDisposable
{
    event EventHandler<ConnectionStateChangedEventArgs>? ConnectionStateChanged;

    event EventHandler<NodeValueChangedEventArgs>? NodeValueChanged;

    bool IsConnected { get; }

    Task ConnectAsync(ConnectionOptions options, CancellationToken cancellationToken);

    Task DisconnectAsync(CancellationToken cancellationToken);
}

public sealed record ConnectionOptions(
    string UserName,
    string Password,
    bool AutoAcceptUntrustedCertificate);

public sealed class ConnectionStateChangedEventArgs(
    bool isConnected,
    string message,
    DateTimeOffset timestamp) : EventArgs
{
    public bool IsConnected { get; } = isConnected;

    public string Message { get; } = message;

    public DateTimeOffset Timestamp { get; } = timestamp;
}

public sealed class NodeValueChangedEventArgs(
    string key,
    object? value,
    bool isGood,
    string status,
    DateTimeOffset sourceTimestamp) : EventArgs
{
    public string Key { get; } = key;

    public object? Value { get; } = value;

    public bool IsGood { get; } = isGood;

    public string Status { get; } = status;

    public DateTimeOffset SourceTimestamp { get; } = sourceTimestamp;
}
