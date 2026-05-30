Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="WSL Control" Height="320" Width="520">
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto" />
      <RowDefinition Height="Auto" />
      <RowDefinition Height="*" />
    </Grid.RowDefinitions>

    <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,0,0,10">
      <Label Content="Distro:" VerticalAlignment="Center" />
      <ComboBox x:Name="DistroBox" Width="180" Margin="6,0,6,0" />
      <Button x:Name="RefreshBtn" Content="Refresh" Width="70" />
    </StackPanel>

    <StackPanel Orientation="Horizontal" Grid.Row="1" Margin="0,0,0,10">
      <Button x:Name="StartBtn" Content="Start" Width="80" Margin="0,0,6,0" />
      <Button x:Name="ShutdownBtn" Content="Shutdown WSL" Width="120" Margin="0,0,6,0" />
      <Button x:Name="ExportBtn" Content="Export Distro" Width="120" Margin="0,0,6,0" />
      <Button x:Name="ImportBtn" Content="Import Distro" Width="120" />
    </StackPanel>

    <TextBox x:Name="OutputBox" Grid.Row="2" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" AcceptsReturn="True" />
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$DistroBox = $window.FindName("DistroBox")
$RefreshBtn = $window.FindName("RefreshBtn")
$StartBtn = $window.FindName("StartBtn")
$ShutdownBtn = $window.FindName("ShutdownBtn")
$ExportBtn = $window.FindName("ExportBtn")
$ImportBtn = $window.FindName("ImportBtn")
$OutputBox = $window.FindName("OutputBox")

function Append-Output([string]$s) {
  $OutputBox.AppendText("$s`n")
  $OutputBox.ScrollToEnd()
}

function Refresh-Distros {
  $list = wsl --list --quiet 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
  $DistroBox.Items.Clear()
  foreach ($d in $list) { $DistroBox.Items.Add($d) | Out-Null }
  if ($DistroBox.Items.Count -gt 0) { $DistroBox.SelectedIndex = 0 }
  Append-Output "Distros refreshed: $($DistroBox.Items.Count)"
}

$RefreshBtn.Add_Click({ Refresh-Distros })

$StartBtn.Add_Click({
  $distro = $DistroBox.SelectedItem
  if ($distro) {
    Append-Output "Starting $distro..."
    wsl -d $distro -- bash -lc "echo 'WSL started: $distro'; sleep 1" 2>&1 | ForEach-Object { Append-Output $_ }
  } else { Append-Output "Select a distro first." }
})

$ShutdownBtn.Add_Click({
  Append-Output "Shutting down WSL..."
  wsl --shutdown
  Append-Output "WSL shutdown complete."
})

$ExportBtn.Add_Click({
  $distro = $DistroBox.SelectedItem
  if (-not $distro) { Append-Output "Select a distro to export."; return }
  $save = [System.IO.Path]::Combine([Environment]::GetFolderPath("Desktop"), "$distro-export.tar")
  Append-Output "Exporting $distro -> $save"
  wsl --export $distro $save 2>&1 | ForEach-Object { Append-Output $_ }
  Append-Output "Export finished."
})

$ImportBtn.Add_Click({
  $dlg = New-Object Microsoft.Win32.OpenFileDialog
  $dlg.Filter = "Tar files|*.tar;*.tar.gz|All files|*.*"
  if ($dlg.ShowDialog() -eq $true) {
    $tar = $dlg.FileName
    $name = [System.IO.Path]::GetFileNameWithoutExtension($tar)
    $installPath = [System.IO.Path]::Combine("$env:USERPROFILE", "WSLImports", $name)
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
    Append-Output "Importing $tar as distro $name to $installPath"
    wsl --import $name $installPath $tar --version 2 2>&1 | ForEach-Object { Append-Output $_ }
    Append-Output "Import finished. Refreshing distros..."
    Refresh-Distros
  }
})

# Initial refresh and show window
Refresh-Distros
$window.ShowDialog() | Out-Null
