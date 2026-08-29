using System.IO;
using System.Windows;
using Bpp.ResistantStation.Hmi.Configuration;

namespace Bpp.ResistantStation.Hmi;

public partial class App : Application
{
    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        var validateOnly = e.Args.Contains("--validate-config", StringComparer.OrdinalIgnoreCase);

        try
        {
            var configurationPath = ResolveConfigurationPath(e.Args);
            var settings = HmiSettings.Load(configurationPath);
            if (validateOnly)
            {
                Shutdown(0);
                return;
            }

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
            if (validateOnly)
            {
                Console.Error.WriteLine($"HMI configuration could not be loaded: {exception.Message}");
                Shutdown(1);
                return;
            }

            MessageBox.Show(
                $"HMI configuration could not be loaded.\n\n{exception.Message}",
                "HMI startup error",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            Shutdown(1);
        }
    }

    private static string ResolveConfigurationPath(IReadOnlyList<string> arguments)
    {
        for (var index = 0; index < arguments.Count; index++)
        {
            var argument = arguments[index];
            if (argument.StartsWith("--config=", StringComparison.OrdinalIgnoreCase))
            {
                return Path.GetFullPath(argument["--config=".Length..]);
            }

            if (!string.Equals(argument, "--config", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            if (index + 1 >= arguments.Count)
            {
                throw new ArgumentException("--config requires a JSON file path.");
            }

            return Path.GetFullPath(arguments[index + 1]);
        }

        return Path.Combine(
            AppContext.BaseDirectory,
            "Configuration",
            "station010.hmi.json");
    }
}
