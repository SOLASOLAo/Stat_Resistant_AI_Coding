using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;

namespace Bpp.ResistantStation.Hmi.Converters;

public sealed class BooleanToBrushConverter : IValueConverter
{
    private static readonly Brush TrueBrush = new SolidColorBrush(Color.FromRgb(55, 166, 103));
    private static readonly Brush FalseBrush = new SolidColorBrush(Color.FromRgb(207, 72, 72));

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        return value is true ? TrueBrush : FalseBrush;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

public sealed class ModeToBrushConverter : IValueConverter
{
    private static readonly Brush ActiveBrush = new SolidColorBrush(Color.FromRgb(0, 110, 168));
    private static readonly Brush InactiveBrush = new SolidColorBrush(Color.FromRgb(226, 233, 239));

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var current = System.Convert.ToInt32(value, CultureInfo.InvariantCulture);
        var expected = System.Convert.ToInt32(parameter, CultureInfo.InvariantCulture);
        return current == expected ? ActiveBrush : InactiveBrush;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

public sealed class ModeToForegroundConverter : IValueConverter
{
    private static readonly Brush ActiveBrush = Brushes.White;
    private static readonly Brush InactiveBrush = new SolidColorBrush(Color.FromRgb(25, 50, 73));

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var current = System.Convert.ToInt32(value, CultureInfo.InvariantCulture);
        var expected = System.Convert.ToInt32(parameter, CultureInfo.InvariantCulture);
        return current == expected ? ActiveBrush : InactiveBrush;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

public sealed class NavigationToBrushConverter : IValueConverter
{
    private static readonly Brush ActiveBrush = new SolidColorBrush(Color.FromRgb(0, 110, 168));
    private static readonly Brush InactiveBrush = Brushes.Transparent;

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var current = System.Convert.ToInt32(value, CultureInfo.InvariantCulture);
        var expected = System.Convert.ToInt32(parameter, CultureInfo.InvariantCulture);
        return current == expected ? ActiveBrush : InactiveBrush;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

public sealed class UnitStateToBrushConverter : IValueConverter
{
    private static readonly Brush ReadyBrush = new SolidColorBrush(Color.FromRgb(55, 166, 103));
    private static readonly Brush TransitionBrush = new SolidColorBrush(Color.FromRgb(230, 164, 46));
    private static readonly Brush FaultBrush = new SolidColorBrush(Color.FromRgb(207, 72, 72));
    private static readonly Brush UnknownBrush = new SolidColorBrush(Color.FromRgb(137, 151, 161));

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var state = System.Convert.ToInt32(value, CultureInfo.InvariantCulture);
        return state switch
        {
            4 or 8 => ReadyBrush,
            18 or 20 or 24 or 34 or 36 or 40 => TransitionBrush,
            1 or 2 => FaultBrush,
            _ => UnknownBrush
        };
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

public sealed class PageVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var current = System.Convert.ToInt32(value, CultureInfo.InvariantCulture);
        var expected = System.Convert.ToInt32(parameter, CultureInfo.InvariantCulture);
        return current == expected ? System.Windows.Visibility.Visible : System.Windows.Visibility.Collapsed;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

public sealed class FixturePositionToBrushConverter : IValueConverter
{
    private static readonly Brush ActiveBrush = new SolidColorBrush(Color.FromRgb(184, 217, 234));
    private static readonly Brush InactiveBrush = new SolidColorBrush(Color.FromRgb(227, 234, 240));

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var current = value?.ToString() ?? string.Empty;
        var expected = parameter?.ToString() ?? string.Empty;
        return current.StartsWith(expected, StringComparison.OrdinalIgnoreCase)
            ? ActiveBrush
            : InactiveBrush;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}
