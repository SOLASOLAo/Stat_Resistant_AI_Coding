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
    private ISession? _session;
    private Subscription? _subscription;

    public event EventHandler<ConnectionStateChangedEventArgs>? ConnectionStateChanged;

    public event EventHandler<NodeValueChangedEventArgs>? NodeValueChanged;

    public bool IsConnected => _session?.Connected == true;

    public async Task ConnectAsync(
        ConnectionOptions options,
        CancellationToken cancellationToken)
    {
        if (IsConnected)
        {
            return;
        }

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
        _session.KeepAlive += OnKeepAlive;

        var namespaceIndex = _session.NamespaceUris.GetIndex(settings.NamespaceUri);
        if (namespaceIndex < 0)
        {
            throw new ServiceResultException(
                StatusCodes.BadNodeIdUnknown,
                $"Data Layer namespace was not advertised: {settings.NamespaceUri}");
        }

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
                StartNodeId = new NodeId(definition.Identifier, (ushort)namespaceIndex),
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

    public async Task DisconnectAsync(CancellationToken cancellationToken)
    {
        var session = _session;
        if (session is null)
        {
            return;
        }

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
            return;
        }

        ConnectionStateChanged?.Invoke(this, new ConnectionStateChangedEventArgs(
            false,
            $"OPC UA keep-alive: {eventArgs.Status}",
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
            NodeValueChanged?.Invoke(this, new NodeValueChangedEventArgs(
                definition.Key,
                value.Value,
                StatusCode.IsGood(value.StatusCode),
                value.StatusCode.ToString(),
                new DateTimeOffset(value.SourceTimestamp.ToLocalTime())));
        }
    }
}
