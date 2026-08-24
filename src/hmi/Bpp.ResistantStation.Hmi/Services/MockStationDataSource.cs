using Bpp.ResistantStation.Hmi.Configuration;

namespace Bpp.ResistantStation.Hmi.Services;

public sealed class MockStationDataSource(HmiSettings settings) : IStationDataSource
{
    private CancellationTokenSource? _loopCancellation;
    private Task? _loopTask;
    private int _tick;

    public event EventHandler<ConnectionStateChangedEventArgs>? ConnectionStateChanged;

    public event EventHandler<NodeValueChangedEventArgs>? NodeValueChanged;

    public bool IsConnected { get; private set; }

    public Task ConnectAsync(ConnectionOptions options, CancellationToken cancellationToken)
    {
        if (IsConnected)
        {
            return Task.CompletedTask;
        }

        IsConnected = true;
        _loopCancellation = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        ConnectionStateChanged?.Invoke(this, new ConnectionStateChangedEventArgs(
            true,
            "Offline demonstration source",
            DateTimeOffset.Now));
        _loopTask = RunAsync(_loopCancellation.Token);
        return Task.CompletedTask;
    }

    public async Task DisconnectAsync(CancellationToken cancellationToken)
    {
        if (!IsConnected)
        {
            return;
        }

        _loopCancellation?.Cancel();
        if (_loopTask is not null)
        {
            try
            {
                await _loopTask.WaitAsync(cancellationToken);
            }
            catch (OperationCanceledException)
            {
                // Expected during shutdown.
            }
        }

        IsConnected = false;
        ConnectionStateChanged?.Invoke(this, new ConnectionStateChangedEventArgs(
            false,
            "Demonstration source stopped",
            DateTimeOffset.Now));
    }

    public async ValueTask DisposeAsync()
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(2));
        await DisconnectAsync(timeout.Token);
        _loopCancellation?.Dispose();
    }

    private async Task RunAsync(CancellationToken cancellationToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMilliseconds(
            Math.Max(settings.PublishingIntervalMs, 250)));

        while (await timer.WaitForNextTickAsync(cancellationToken))
        {
            _tick++;
            var phase = (_tick / 12) % 4;
            var modeId = phase switch
            {
                0 => 4,
                1 or 2 => 1,
                _ => 3
            };
            var autoInfo = phase switch
            {
                0 => 4,
                1 => 10,
                2 => 12,
                _ => 16
            };

            Publish("ModeId", modeId);
            Publish("ModeRelease", true);
            Publish("IsRunning", phase is 1 or 2);
            Publish("IsStopping", false);
            Publish("ExecState", phase is 1 or 2 ? 32 : 16);
            Publish("Token", 1);
            Publish("AutoInfoLine", autoInfo);
            Publish("IsInHomePosition", phase is 0 or 3);
            Publish("BusOk", true);
            Publish("SafetyDoorBase", phase is 0 or 3);
            Publish("SafetyDoorWork", phase is 1 or 2);
            Publish("PressingCylinderBase", phase is not 2);
            Publish("PressingCylinderWork", phase is 2);
            Publish("ResistantUnitState", 4);
            Publish("KistlerUnitState", 4);
            Publish("FixtureLeft", phase == 0);
            Publish("FixtureMiddle", phase is 1 or 2);
            Publish("FixtureRight", phase == 3);
            Publish("ProductSensorA", true);
            Publish("ProductSensorB", true);
            Publish("EmergencyCircuitOk", true);
            Publish("MaintenanceCircuitOk", true);
            Publish("SafetyDoorCircuitOk", true);
            Publish("AllSafetyCircuitsOk", true);
        }
    }

    private void Publish(string key, object value)
    {
        NodeValueChanged?.Invoke(this, new NodeValueChangedEventArgs(
            key,
            value,
            true,
            "Good (demo)",
            DateTimeOffset.Now));
    }
}
