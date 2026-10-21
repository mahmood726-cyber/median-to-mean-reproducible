# capture_edge.ps1 — Microsoft Edge headless screenshots of the figure pages (one at a time; lane-local profile).
#   powershell -ExecutionPolicy Bypass -File figures\capture_edge.ps1
$root = Split-Path -Parent $PSScriptRoot
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$prof = Join-Path $root "..\work\edge-profile"
$ver = (Get-Item $edge).VersionInfo.ProductVersion
"Edge $ver"
$panels = @(
  @{ name = "fig1a_W06_nonsurvivors"; w = 1300; h = 760 },
  @{ name = "fig1b_W06_survivors";    w = 1300; h = 760 },
  @{ name = "fig2_invalid_n";         w = 1300; h = 620 }
)
foreach ($p in $panels) {
  $page = Join-Path $root ("figures\pages\" + $p.name + "\median-to-mean\index.html")
  $url = "file:///" + ($page -replace '\\', '/')
  $out = Join-Path $root ("figures\" + $p.name + ".png")
  $args = @("--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check", "--user-data-dir=`"$prof`"",
            "--hide-scrollbars", "--force-device-scale-factor=2", "--window-size=$($p.w),$($p.h)",
            "--virtual-time-budget=5000", "--screenshot=`"$out`"", "`"$url`"")
  $proc = Start-Process -FilePath $edge -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
  "{0}: exit {1}, exists {2}" -f $p.name, $proc.ExitCode, (Test-Path $out)
}
