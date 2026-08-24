using System.Windows;

namespace Bpp.ResistantStation.Hmi;

public partial class ConnectionDialog : Window
{
    public ConnectionDialog(string endpointUrl)
    {
        InitializeComponent();
        DataContext = new { EndpointUrl = endpointUrl };
    }

    public string UserName => UserNameInput.Text;

    public string Password => PasswordInput.Password;

    public bool AutoAcceptUntrustedCertificate => AcceptCertificateInput.IsChecked == true;

    private void OnConnectClick(object sender, RoutedEventArgs e)
    {
        DialogResult = true;
    }

    private void OnCancelClick(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
    }
}
