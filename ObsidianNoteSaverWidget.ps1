param(
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

$Script:AppCmd = Join-Path $PSScriptRoot 'ObsidianNoteSaver.cmd'
$Script:IconPath = Join-Path $PSScriptRoot 'Assets\obsidian-note-saver-penguin.ico'
$Script:LogoPath = Join-Path $PSScriptRoot 'Assets\obsidian-note-saver-penguin.png'

if ($SelfTest) {
    "AppCmd: " + (Test-Path -LiteralPath $Script:AppCmd)
    "Icon: " + (Test-Path -LiteralPath $Script:IconPath)
    "Logo: " + (Test-Path -LiteralPath $Script:LogoPath)
    exit 0
}

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="250"
        Height="96"
        WindowStyle="None"
        ResizeMode="NoResize"
        AllowsTransparency="True"
        Background="Transparent"
        Topmost="True"
        ShowInTaskbar="False"
        FontFamily="Malgun Gothic"
        FontSize="13">
    <Border x:Name="RootCard" CornerRadius="24" Background="#FAFCFF" BorderBrush="#DDE6F3" BorderThickness="1" Padding="12">
        <Border.Effect>
            <DropShadowEffect BlurRadius="18" ShadowDepth="4" Opacity="0.20" Color="#1F2937"/>
        </Border.Effect>
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="52"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="30"/>
            </Grid.ColumnDefinitions>
            <Image x:Name="LogoImage" Width="44" Height="44" Stretch="Uniform" VerticalAlignment="Center"/>
            <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="8,0,0,0">
                <TextBlock Text="Note Saver" FontWeight="Bold" Foreground="#1F2937"/>
                <Button x:Name="OpenButton"
                        Content="새 메모"
                        Margin="0,7,0,0"
                        Height="30"
                        Padding="14,4"
                        Background="#3182F6"
                        Foreground="White"
                        BorderThickness="0"
                        Cursor="Hand"/>
            </StackPanel>
            <Button x:Name="CloseButton"
                    Grid.Column="2"
                    Content="x"
                    Width="26"
                    Height="26"
                    VerticalAlignment="Top"
                    Background="#EEF4FF"
                    Foreground="#64748B"
                    BorderThickness="0"
                    Cursor="Hand"/>
        </Grid>
    </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

if (Test-Path -LiteralPath $Script:IconPath) {
    $window.Icon = New-Object System.Windows.Media.Imaging.BitmapImage([System.Uri]$Script:IconPath)
}

$LogoImage = $window.FindName('LogoImage')
$OpenButton = $window.FindName('OpenButton')
$CloseButton = $window.FindName('CloseButton')
$RootCard = $window.FindName('RootCard')

if (Test-Path -LiteralPath $Script:LogoPath) {
    $LogoImage.Source = New-Object System.Windows.Media.Imaging.BitmapImage([System.Uri]$Script:LogoPath)
}

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$window.Left = $screen.Right - $window.Width - 24
$window.Top = $screen.Bottom - $window.Height - 36

$RootCard.Add_MouseLeftButtonDown({
    try {
        $window.DragMove()
    }
    catch {
    }
})

$OpenButton.Add_Click({
    if (Test-Path -LiteralPath $Script:AppCmd) {
        Start-Process -FilePath $Script:AppCmd -WorkingDirectory $PSScriptRoot
    }
})

$CloseButton.Add_Click({
    $window.Close()
})

[void]$window.ShowDialog()
