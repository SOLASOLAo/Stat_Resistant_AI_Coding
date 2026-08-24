using System.IO;
using System.Windows;
using Bpp.ResistantStation.Hmi.Configuration;

namespace Bpp.ResistantStation.Hmi;

public partial class App : Application
{
    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        var configurationPath = Path.Combine(
            AppContext.BaseDirectory,
            "Configuration",
            "station010.hmi.json");

        try
        {
            var settings = HmiSettings.Load(configurationPath);
            var mainWindow = new MainWindow(settings);
            MainWindow = mainWindow;
            mainWindow.Show();

            if (e.Args.Contains("--demo", StringComparer.OrdinalIgnoreCase))
            {
                await mainWindow.StartDemoAsync();
            }
        }
        catch (Exception exception)
        {
            MessageBox.Show(
                $"HMI configuration could not be loaded.\n\n{exception.Message}",
                "BPP HMI startup error",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            Shutdown(1);
        }
    }
}
