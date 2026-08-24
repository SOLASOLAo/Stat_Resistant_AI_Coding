using System.Windows;
using System.Windows.Controls;
using Bpp.ResistantStation.Hmi.Configuration;
using Bpp.ResistantStation.Hmi.Services;
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

    private async void OnStationCommandClick(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement element)
        {
            return;
        }

        var command = element.Tag?.ToString() switch
        {
            "Start" => StationCommand.Start,
            "Stop" => StationCommand.Stop,
            "ToggleStep" when _viewModel.IsStepping => StationCommand.DisableStepMode,
            "ToggleStep" => StationCommand.EnableStepMode,
            "StepPulse" => StationCommand.StepPulse,
            _ => (StationCommand?)null
        };
        if (command is null)
        {
            return;
        }

        await RunUiActionAsync(async () =>
        {
            var result = await _viewModel.RequestStationCommandAsync(
                command.Value,
                CancellationToken.None);
            if (!result.Accepted)
            {
                MessageBox.Show(
                    result.Message,
                    "Chain control / Chain 控制",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
            }
        });
    }

    private async void OnManualFunctionClick(object sender, RoutedEventArgs e)
    {
        if (sender is not Button { DataContext: ManualActionRow action })
        {
            return;
        }

        await RunUiActionAsync(async () =>
        {
            var startResult = await _viewModel.SetManualFunctionAsync(
                action,
                execute: true,
                CancellationToken.None);
            if (!startResult.Accepted)
            {
                MessageBox.Show(
                    startResult.Message,
                    "Manual function / 手动功能",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
                return;
            }

            // DEMO emulates a short operator press. The real adapter keeps every
            // Unit command locked until Nexeed heartbeat and pulse semantics are commissioned.
            await Task.Delay(TimeSpan.FromMilliseconds(750));
            await _viewModel.SetManualFunctionAsync(
                action,
                execute: false,
                CancellationToken.None);
        });
    }

    private void OnEtherCatSelectionChanged(
        object sender,
        RoutedPropertyChangedEventArgs<object> e)
    {
        if (e.NewValue is EtherCatTopologyNode node)
        {
            _viewModel.SelectedEtherCatNode = node;
        }
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
