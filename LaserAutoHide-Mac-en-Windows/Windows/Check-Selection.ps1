$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'LaserAutoHide.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$fn = $ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Select-Show'}, $true)
. ([scriptblock]::Create($fn.Extent.Text))
$first = [pscustomobject]@{Key=100; Laser=$false}
$second = [pscustomobject]@{Key=200; Laser=$true}
if ($null -ne (Select-Show @() 0 $false)) { throw 'Empty collection' }
if ((Select-Show @($first) 0 $false).Key -ne 100) { throw 'Single show' }
if ((Select-Show @($first,$second) 0 $false).Key -ne 200) { throw 'Laser on second show' }
if ((Select-Show @($first,$second) 100 $false).Key -ne 200) { throw 'Switch from non-laser window' }
if ((Select-Show @($first,$second) 100 $true).Key -ne 100) { throw 'Restore ownership lost' }
if ((Select-Show @($second) 100 $true).Key -ne 200) { throw 'Closed window not released' }
$second.Laser = $false
if ((Select-Show @($first,$second) 200 $false).Key -ne 200) { throw 'Stable selection' }
Write-Host 'PASS: syntax and selection for zero/one/multiple windows, laser priority, hidden ownership, closed window, stable selection.'
Write-Host 'Windows/PowerPoint COM and visual laser behavior have not been tested here.'

$init = $ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Set-SelectedView'}, $true)
. ([scriptblock]::Create($init.Extent.Text))
$script:restoreCalls = 0
function Restore-Pointer { $script:restoreCalls++ }
$script:watch = [Diagnostics.Stopwatch]::StartNew()
$script:view = $null
$script:viewKey = 0
$script:wasLaser = $true
$fakeView = [pscustomobject]@{LaserPointerEnabled=$true; PointerType=0; State=2}
# Exact initialization regression: key 0 must not leave the view null.
Set-SelectedView ([pscustomobject]@{Key=0; View=$fakeView})
if ($null -eq $script:view -or $script:wasLaser) { throw 'Zero-key initialization failed' }
if ($script:restoreCalls -ne 1) { throw 'Initialization restore count' }
Set-SelectedView ([pscustomobject]@{Key=0; View=$fakeView})
if ($script:restoreCalls -ne 1) { throw 'Same view must not reset idle timer' }
Set-SelectedView ([pscustomobject]@{Key=42; View=$fakeView})
if ($script:restoreCalls -ne 2 -or $script:viewKey -ne 42) { throw 'Changed view not initialized' }
$source = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'LaserAutoHide.ps1') -Raw
if ($source -match '\$(window|show)\.HWND') { throw 'Unsupported HWND dependency remains' }
Write-Host 'PASS: null/zero-key initialization, stable timer, changed view; no SlideShowWindow.HWND reads.'

foreach ($name in @('Restore-Pointer','Update-Laser','Get-ViewKey')) {
    $fn = $ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name}.GetNewClosure(), $true)
    . ([scriptblock]::Create($fn.Extent.Text))
}
$script:writes = [Collections.Generic.List[string]]::new()
$v = [pscustomobject]@{ Pointer=0; Laser=$true }
$v | Add-Member ScriptProperty PointerType { $this.Pointer } { param($value) $this.Pointer=$value; $script:writes.Add("pointer=$value") }
$v | Add-Member ScriptProperty LaserPointerEnabled { $this.Laser } { param($value) $this.Laser=$value; $script:writes.Add("laser=$value") }
$script:view=$v; $script:hidden=$false; $script:wasLaser=$false; $script:last=0
Update-Laser 0 $false 4
Update-Laser 3.9 $false 4
if ($script:writes.Count -ne 0) { throw 'Hidden before timeout' }
# Model the host: the laser remains visible independently of PointerType.
foreach ($time in 4..20) { Update-Laser $time $false 4 }
if (($script:writes -join '|') -ne 'laser=False|pointer=3' -or -not $script:hidden -or $v.Laser -or $v.Pointer -ne 3) { throw 'Idle caused repeated pointer changes' }
Update-Laser 21 $true 4
if (($script:writes -join '|') -ne 'laser=False|pointer=3|pointer=4|laser=True' -or $script:hidden) { throw 'Movement did not restore laser in automatic arrow mode' }
# Simulate PowerPoint representing active laser as pointer type 0 again.
$v.Pointer=0
Update-Laser 24 $false 4
if ($script:writes.Count -ne 4) { throw 'Second hide too early' }
Update-Laser 25 $false 4
if ($script:writes.Count -ne 6 -or $script:writes[4] -ne 'laser=False' -or $script:writes[5] -ne 'pointer=3') { throw 'Second idle hide failed' }
$v.Pointer=2; $v.Laser=$false
Update-Laser 26 $true 4
if ($script:hidden -or $script:writes.Count -ne 6) { throw 'Manual pen was overwritten' }
$w1=[pscustomobject]@{Presentation=[pscustomobject]@{FullName='fixture.pptx'};View=[pscustomobject]@{}}
$w2=[pscustomobject]@{Presentation=[pscustomobject]@{FullName='fixture.pptx'};View=[pscustomobject]@{}}
if ((Get-ViewKey $w1 1) -ne (Get-ViewKey $w2 1)) { throw 'View recreation changed identity' }
Write-Host 'PASS: 20 seconds idle without reappearance, movement-only restore, automatic arrow mode, next idle cycle, manual pen and stable presentation identity.'
