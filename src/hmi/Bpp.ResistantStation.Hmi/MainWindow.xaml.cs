using System.Windows;
using Bpp.ResistantStation.Hmi.Configuration;
using Bpp.ResistantStation.Hmi.ViewModels;

namespace Bpp.ResistantStation.Hmi;

public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel;

    public MainWindow(HmiSettings settings)
    {
        InitializeComponent();
        _viewModel = new MainViewModel(settings);
        DataContext = _viewModel;
    }

    public Task StartDemoAsync() => _viewModel.ConnectAsync(
        useDemo: true,
        string.Empty,
        string.Empty,
        autoAcceptUntrustedCertificate: false,
        enableModeRequests: true,
        CancellationToken.None);

    private async void OnConnectPlcClick(object sender, RoutedEventArgs e)
    {
        var dialog = new ConnectionDialog(_viewModel.EndpointUrl)
        {
            Owner = this
        };
        if (dialog.ShowDialog() != true)
        {
            return;
        }

        await RunUiActionAsync(() => _viewModel.ConnectAsync(
            useDemo: false,
            dialog.UserName,
            dialog.Password,
            dialog.AutoAcceptUntrustedCertificate,
            dialog.EnableModeRequests,
            CancellationToken.None));
    }

    private async void OnDemoClick(object sender, RoutedEventArgs e)
    {
        await RunUiActionAsync(StartDemoAsync);
    }

    private async void OnDisconnectClick(object sender, RoutedEventArgs e)
    {
        await RunUiActionAsync(() => _viewModel.DisconnectAsync(CancellationToken.None));
    }

    private void OnNavigateClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement element &&
            int.TryParse(element.Tag?.ToString(), out var pageIndex))
        {
            _viewModel.SelectPage(pageIndex);
        }
    }

    private async void OnModeClick(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement element ||
            !byte.TryParse(element.Tag?.ToString(), out var modeId))
        {
            return;
        }

        await RunUiActionAsync(async () =>
        {
            var result = await _viewModel.RequestModeAsync(modeId, CancellationToken.None);
            if (!result.Accepted)
            {
                MessageBox.Show(
                    result.Message,
                    "Mode request / 模式切换",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
            }
        });
    }

    protected override async void OnClosed(EventArgs e)
    {
        await _viewModel.DisposeAsync();
        base.OnClosed(e);
    }

    private static async Task RunUiActionAsync(Func<Task> action)
    {
        try
        {
            await action();
        }
        catch (Exception exception)
        {
            MessageBox.Show(
                exception.GetBaseException().Message,
                "HMI connection",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
        }
    }
}
