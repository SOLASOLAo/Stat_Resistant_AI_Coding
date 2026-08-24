using System.IO;
using System.Text;
using Bpp.ResistantStation.Hmi.Configuration;
using Opc.Ua;
using Opc.Ua.Client;
using Opc.Ua.Configuration;

namespace Bpp.ResistantStation.Hmi.Services;

public sealed class OpcUaReadOnlyDataSource(HmiSettings settings) : IStationDataSource
{
    private const string ApplicationName = "BPP Resistance Station HMI";
    private readonly ITelemetryContext _telemetry = DefaultTelemetry.Create(_ => { });
    private readonly IReadOnlyDictionary<string, HmiNodeDefinition> _nodesByKey =
        settings.Nodes.ToDictionary(node => node.Key, StringComparer.Ordinal);
    private ISession? _session;
    private Subscription? _subscription;
    private SessionReconnectHandler? _reconnectHandler;
    private ushort _namespaceIndex;
    private bool _modeRequestsEnabled;

    public event EventHandler<ConnectionStateChangedEventArgs>? ConnectionStateChanged;

    public event EventHandler<NodeValueChangedEventArgs>? NodeValueChanged;

    public bool IsConnected => _session?.Connected == true;

    public bool SupportsModeRequests => _modeRequestsEnabled;

    public async Task ConnectAsync(
        ConnectionOptions options,
        CancellationToken cancellationToken)
    {
        if (IsConnected)
        {
            return;
        }

        _modeRequestsEnabled = settings.ModeControl.Enabled && options.EnableModeRequests;

        var configuration = await CreateConfigurationAsync(
            options,
            _telemetry,
            cancellationToken);
        var application = new ApplicationInstance(configuration, _telemetry);

        await application.CheckApplicationInstanceCertificatesAsync(
            false,
            2048,
            cancellationToken);

        var endpointDescription = await CoreClientUtils.SelectEndpointAsync(
            configuration,
            settings.EndpointUrl,
            useSecurity: true,
            discoverTimeout: 15_000,
            _telemetry,
            cancellationToken);
        var endpoint = new ConfiguredEndpoint(
            null,
            endpointDescription,
            EndpointConfiguration.Create(configuration));
        IUserIdentity identity = string.IsNullOrWhiteSpace(options.UserName)
            ? new UserIdentity(new AnonymousIdentityToken())
            : new UserIdentity(options.UserName, Encoding.UTF8.GetBytes(options.Password));

        var sessionFactory = new DefaultSessionFactory(_telemetry);
        _session = await sessionFactory.CreateAsync(
            configuration,
            endpoint,
            updateBeforeConnect: false,
            checkDomain: false,
            sessionName: ApplicationName,
            sessionTimeout: 60_000,
            identity,
            preferredLocales: ["zh-CN", "en-US"]);
        _session.KeepAliveInterval = Math.Max(500, settings.StaleTimeoutMs / 2);
        _session.KeepAlive += OnKeepAlive;

        var namespaceIndex = _session.NamespaceUris.GetIndex(settings.NamespaceUri);
        if (namespaceIndex < 0)
        {
            throw new ServiceResultException(
                StatusCodes.BadNodeIdUnknown,
                $"Data Layer namespace was not advertised: {settings.NamespaceUri}");
        }

        _namespaceIndex = (ushort)namespaceIndex;

        _subscription = new Subscription(_session.DefaultSubscription)
        {
            DisplayName = "Station010 read-only overview",
            PublishingInterval = settings.PublishingIntervalMs,
            KeepAliveCount = 20,
            LifetimeCount = 60,
            PublishingEnabled = true
        };

        foreach (var definition in settings.Nodes.Where(node => node.Enabled))
        {
            var item = new MonitoredItem(_subscription.DefaultItem)
            {
                DisplayName = definition.Key,
                StartNodeId = new NodeId(definition.Identifier, _namespaceIndex),
                AttributeId = Attributes.Value,
                SamplingInterval = settings.PublishingIntervalMs,
                QueueSize = 1,
                DiscardOldest = true,
                Handle = definition
            };
            item.Notification += OnNotification;
            _subscription.AddItem(item);
        }

        _session.AddSubscription(_subscription);
        await _subscription.CreateAsync(cancellationToken);
        ConnectionStateChanged?.Invoke(this, new ConnectionStateChangedEventArgs(
            true,
            $"Connected to {settings.EndpointUrl}",
            DateTimeOffset.Now));
    }

    public async Task<ModeRequestResult> RequestModeAsync(
        byte modeId,
        CancellationToken cancellationToken)
    {
        if (!_modeRequestsEnabled ||
            !settings.ModeControl.AllowedModeIds.Contains(modeId))
        {
            return new ModeRequestResult(
                false,
                modeId,
                "Mode requests are disabled for this session or the mode ID is not allowlisted.");
        }

        if (!IsConnected)
        {
            return new ModeRequestResult(false, modeId, "OPC UA is not connected.");
        }

        var safetyKeys = new[]
        {
            "EmergencyCircuitOk",
            "MaintenanceCircuitOk"
        };
        var prerequisiteKeys = modeId == 5
            ? safetyKeys.Append("StationIsEmpty").ToArray()
            : safetyKeys;
        var prerequisiteValues = await ReadCurrentValuesAsync(
            prerequisiteKeys,
            cancellationToken);
        var missingSafety = safetyKeys
            .Where(key => !IsGoodTrue(prerequisiteValues[key]))
            .ToArray();
        if (missingSafety.Length > 0)
        {
            return new ModeRequestResult(
                false,
                modeId,
                $"Mode request safety feedback is not Good/TRUE: {string.Join(", ", missingSafety)}");
        }

        if (modeId == 5 && !IsGoodTrue(prerequisiteValues["StationIsEmpty"]))
        {
            return new ModeRequestResult(
                false,
                modeId,
                "Change-over requires Station.Unit.IsEmpty = TRUE.");
        }

        await WriteAllowlistedByteAsync(
            settings.ModeControl.TokenRequestIdentifier,
            settings.ModeControl.PanelToken,
            cancellationToken);

        if (!await WaitForValueAsync(
                "Token",
                value => value is byte token &&
                    token == settings.ModeControl.PanelToken,
                cancellationToken))
        {
            return new ModeRequestResult(
                false,
                modeId,
                "The HMI token was not granted before the timeout.");
        }

        await WriteAllowlistedByteAsync(
            settings.ModeControl.ModeIdRequestIdentifier,
            modeId,
            cancellationToken);

        var accepted = await WaitForValueAsync(
            "ModeId",
            value => Convert.ToByte(value) == modeId,
            cancellationToken);
        return accepted
            ? new ModeRequestResult(true, modeId, "PLC confirmed the requested mode.")
            : new ModeRequestResult(
                false,
                modeId,
                "PLC did not confirm the requested mode before the timeout.");
    }

    public async Task DisconnectAsync(CancellationToken cancellationToken)
    {
        _modeRequestsEnabled = false;
        var session = _session;
        if (session is null)
        {
            return;
        }

        _reconnectHandler?.CancelReconnect();
        _reconnectHandler?.Dispose();
        _reconnectHandler = null;

        if (_subscription is not null)
        {
            foreach (var item in _subscription.MonitoredItems)
            {
                item.Notification -= OnNotification;
            }

            await _subscription.DeleteAsync(silent: true, cancellationToken);
            await session.RemoveSubscriptionAsync(_subscription, cancellationToken);
            _subscription.Dispose();
            _subscription = null;
        }

        session.KeepAlive -= OnKeepAlive;
        await session.CloseAsync(2_000, closeChannel: true, cancellationToken);
        session.Dispose();
        _session = null;
        ConnectionStateChanged?.Invoke(this, new ConnectionStateChangedEventArgs(
            false,
            "OPC UA session closed",
            DateTimeOffset.Now));
    }

    public async ValueTask DisposeAsync()
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(3));
        await DisconnectAsync(timeout.Token);
    }

    private static async Task<ApplicationConfiguration> CreateConfigurationAsync(
        ConnectionOptions options,
        ITelemetryContext telemetry,
        CancellationToken cancellationToken)
    {
        var pkiRoot = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Bpp.ResistantStation.Hmi",
            "pki");
        var configuration = new ApplicationConfiguration(telemetry)
        {
            ApplicationName = ApplicationName,
            ApplicationUri = $"urn:{Utils.GetHostName()}:Bpp:ResistanceStation:Hmi",
            ProductUri = "urn:Bpp:ResistanceStation:Hmi",
            ApplicationType = ApplicationType.Client,
            SecurityConfiguration = new SecurityConfiguration
            {
                ApplicationCertificate = new CertificateIdentifier
                {
                    StoreType = CertificateStoreType.Directory,
                    StorePath = Path.Combine(pkiRoot, "own"),
                    SubjectName = $"CN={ApplicationName}, O=BPP"
                },
                TrustedPeerCertificates = new CertificateTrustList
                {
                    StoreType = CertificateStoreType.Directory,
                    StorePath = Path.Combine(pkiRoot, "trusted")
                },
                TrustedIssuerCertificates = new CertificateTrustList
                {
                    StoreType = CertificateStoreType.Directory,
                    StorePath = Path.Combine(pkiRoot, "issuer")
                },
                RejectedCertificateStore = new CertificateTrustList
                {
                    StoreType = CertificateStoreType.Directory,
                    StorePath = Path.Combine(pkiRoot, "rejected")
                },
                AutoAcceptUntrustedCertificates = options.AutoAcceptUntrustedCertificate,
                RejectSHA1SignedCertificates = true,
                MinimumCertificateKeySize = 2048
            },
            TransportConfigurations = [],
            TransportQuotas = new TransportQuotas
            {
                OperationTimeout = 15_000,
                MaxStringLength = 1_048_576,
                MaxByteStringLength = 1_048_576,
                MaxArrayLength = 65_535,
                MaxMessageSize = 4_194_304,
                MaxBufferSize = 65_535,
                ChannelLifetime = 300_000,
                SecurityTokenLifetime = 3_600_000
            },
            ClientConfiguration = new ClientConfiguration
            {
                DefaultSessionTimeout = 60_000,
                MinSubscriptionLifetime = 10_000
            }
        };

        await configuration.ValidateAsync(ApplicationType.Client, cancellationToken);
        return configuration;
    }

    private void OnKeepAlive(ISession session, KeepAliveEventArgs eventArgs)
    {
        if (ServiceResult.IsGood(eventArgs.Status))
        {
            ConnectionStateChanged?.Invoke(this, new ConnectionStateChangedEventArgs(
                true,
                "OPC UA session healthy",
                DateTimeOffset.Now));
            return;
        }

        ConnectionStateChanged?.Invoke(this, new ConnectionStateChangedEventArgs(
            false,
            $"OPC UA keep-alive: {eventArgs.Status}",
            DateTimeOffset.Now));

        if (_reconnectHandler is null)
        {
            _reconnectHandler = new SessionReconnectHandler(
                _telemetry,
                reconnectAbort: true,
                settings.ReconnectDelayMs);
            _reconnectHandler.BeginReconnect(
                session,
                settings.ReconnectDelayMs,
                OnReconnectComplete);
        }
    }

    private void OnReconnectComplete(object? sender, EventArgs eventArgs)
    {
        if (!ReferenceEquals(sender, _reconnectHandler) || _reconnectHandler?.Session is null)
        {
            return;
        }

        _session = _reconnectHandler.Session;
        _reconnectHandler.Dispose();
        _reconnectHandler = null;
        ConnectionStateChanged?.Invoke(this, new ConnectionStateChangedEventArgs(
            true,
            "OPC UA session reconnected",
            DateTimeOffset.Now));
    }

    private void OnNotification(MonitoredItem item, MonitoredItemNotificationEventArgs eventArgs)
    {
        if (item.Handle is not HmiNodeDefinition definition)
        {
            return;
        }

        foreach (var value in item.DequeueValues())
        {
            var isGood = StatusCode.IsGood(value.StatusCode);
            NodeValueChanged?.Invoke(this, new NodeValueChangedEventArgs(
                definition.Key,
                value.Value,
                isGood,
                value.StatusCode.ToString(),
                new DateTimeOffset(value.SourceTimestamp.ToLocalTime())));
        }
    }

    private async Task WriteAllowlistedByteAsync(
        string identifier,
        byte value,
        CancellationToken cancellationToken)
    {
        var allowed = identifier == settings.ModeControl.TokenRequestIdentifier ||
            identifier == settings.ModeControl.ModeIdRequestIdentifier;
        if (!allowed)
        {
            throw new InvalidOperationException("Rejected OPC UA write outside the mode allowlist.");
        }

        var session = _session ?? throw new InvalidOperationException("OPC UA is not connected.");
        var response = await session.WriteAsync(
            null,
            new WriteValueCollection
            {
                new()
                {
                    NodeId = new NodeId(identifier, _namespaceIndex),
                    AttributeId = Attributes.Value,
                    Value = new DataValue { Value = value }
                }
            },
            cancellationToken);
        if (response.Results.Count != 1 || StatusCode.IsBad(response.Results[0]))
        {
            var status = response.Results.Count == 0
                ? "no status returned"
                : response.Results[0].ToString();
            throw new ServiceResultException($"Mode request write failed: {status}");
        }
    }

    private async Task<bool> WaitForValueAsync(
        string key,
        Func<object?, bool> predicate,
        CancellationToken cancellationToken)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(settings.ModeControl.RequestTimeoutMs);
        try
        {
            while (!timeout.IsCancellationRequested)
            {
                var values = await ReadCurrentValuesAsync([key], timeout.Token);
                var current = values[key];
                if (StatusCode.IsGood(current.StatusCode) &&
                    predicate(current.Value))
                {
                    return true;
                }

                await Task.Delay(100, timeout.Token);
            }
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return false;
        }

        return false;
    }

    private async Task<IReadOnlyDictionary<string, DataValue>> ReadCurrentValuesAsync(
        IReadOnlyCollection<string> keys,
        CancellationToken cancellationToken)
    {
        var session = _session ?? throw new InvalidOperationException("OPC UA is not connected.");
        var definitions = keys.Select(key =>
        {
            if (!_nodesByKey.TryGetValue(key, out var definition))
            {
                throw new InvalidOperationException($"Unknown OPC UA catalog key: {key}");
            }

            return definition;
        }).ToArray();

        var nodesToRead = new ReadValueIdCollection();
        foreach (var definition in definitions)
        {
            nodesToRead.Add(new ReadValueId
            {
                NodeId = new NodeId(definition.Identifier, _namespaceIndex),
                AttributeId = Attributes.Value
            });
        }

        var response = await session.ReadAsync(
            null,
            maxAge: 0,
            TimestampsToReturn.Neither,
            nodesToRead,
            cancellationToken);
        if (response.Results.Count != definitions.Length)
        {
            throw new ServiceResultException("OPC UA prerequisite read returned an unexpected result count.");
        }

        var values = new Dictionary<string, DataValue>(definitions.Length, StringComparer.Ordinal);
        for (var index = 0; index < definitions.Length; index++)
        {
            values[definitions[index].Key] = response.Results[index];
        }

        return values;
    }

    private static bool IsGoodTrue(DataValue value) =>
        StatusCode.IsGood(value.StatusCode) &&
        value.Value is true;
}
