Add-Type -AssemblyName PresentationFramework

function Add-Log {
    param ($msg, $isError = $false)
    if ($isError) {
        $OutputBox.AppendText("❌ $msg`n")
        $OutputBox.SelectionColor = 'Red'
    } else {
        $OutputBox.AppendText("✅ $msg`n")
        $OutputBox.SelectionColor = 'Green'
    }
}

function Set-SvcHostSplitThreshold {
    try {
        $ram = (Get-CimInstance CIM_ComputerSystem).TotalPhysicalMemory / 1GB
        $value = switch ($ram) {
            { $_ -ge 32 } { 2000000 }
            { $_ -ge 16 } { 1000000 }
            { $_ -ge 8 } { 500000 }
            default { 300000 }
        }

        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $value -Type DWord
        Add-Log "Set SvcHostSplitThresholdInKB to $value"
    } catch {
        Add-Log "Failed to set SvcHostSplitThresholdInKB: $_" $true
    }
}

function Disable-ServiceSafe {
    param ($name)
    try {
        Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $name -StartupType Disabled
        Add-Log "Disabled service: $name"
    } catch {
        Add-Log "Failed to disable service $name: $_" $true
    }
}

function Enable-ServiceSafe {
    param ($name)
    try {
        Set-Service -Name $name -StartupType Manual
        Add-Log "Restored service: $name"
    } catch {
        Add-Log "Failed to restore service $name: $_" $true
    }
}

function Disable-Task {
    param ($path)
    try {
        schtasks /Change /TN $path /Disable | Out-Null
        Add-Log "Disabled task: $path"
    } catch {
        Add-Log "Failed to disable task: $path" $true
    }
}

function Enable-Task {
    param ($path)
    try {
        schtasks /Change /TN $path /Enable | Out-Null
        Add-Log "Restored task: $path"
    } catch {
        Add-Log "Failed to restore task: $path" $true
    }
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
        Title="System Tweaker - by fahad" Height="400" Width="600" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Grid Background="#1e1e1e">
        <TextBlock Text="by fahad" Foreground="Red" FontSize="18" HorizontalAlignment="Center" Margin="0,10,0,0"/>
        
        <TextBox x:Name="OutputBox" Margin="20,50,20,80" VerticalScrollBarVisibility="Auto" IsReadOnly="True" Background="#111" Foreground="White" FontFamily="Consolas" />

        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Bottom" Margin="0,0,0,20">
            <Button x:Name="StartButton" Content="Start Process" Width="120" Height="40" Margin="10" Background="Green" Foreground="White"/>
            <Button x:Name="RestoreButton" Content="Restore" Width="120" Height="40" Margin="10" Background="DarkRed" Foreground="White"/>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$OutputBox = $window.FindName("OutputBox")
$StartButton = $window.FindName("StartButton")
$RestoreButton = $window.FindName("RestoreButton")

$StartButton.Add_Click({
    $OutputBox.Clear()

    Disable-ServiceSafe "SysMain"
    Disable-ServiceSafe "DiagTrack"
    Disable-ServiceSafe "Spooler"

    Disable-Task "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    Disable-Task "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    Disable-Task "\Microsoft\Windows\Application Experience\StartupAppTask"
    Disable-Task "\Microsoft\Windows\Application Experience\PcaPatchDbTask"

    Set-SvcHostSplitThreshold
})

$RestoreButton.Add_Click({
    $OutputBox.Clear()

    Enable-ServiceSafe "SysMain"
    Enable-ServiceSafe "DiagTrack"
    Enable-ServiceSafe "Spooler"

    Enable-Task "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    Enable-Task "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    Enable-Task "\Microsoft\Windows\Application Experience\StartupAppTask"
    Enable-Task "\Microsoft\Windows\Application Experience\PcaPatchDbTask"
})

$window.ShowDialog() | Out-Null
