# TESTE DO INSTALADOR DO CAIXA NUM WINDOWS LIMPO (13/11/2026, pedido do Pedro).
# Uso: teste.ps1 -Caso <controle|normal|corrompido|atualizacao>
#  controle    : 1.0.0 e depois a 1.1.0 por cima. ESPERADO: TRAVA ou falha (o defeito que o Pedro viu).
#  normal      : 1.0.0 (o desinstalador dela como sai do instalador) e a 1.2.0 por cima. ESPERADO: instala.
#  corrompido  : 1.0.0, o desinstalador instalado estragado de propósito, e a 1.2.0 por cima. ESPERADO: instala.
#  atualizacao : 1.1.0 e a 1.2.0 por cima (o caminho da atualização sozinha). ESPERADO: instala.
param([string]$Caso)
$ErrorActionPreference = "Stop"
$pasta = Join-Path $env:LOCALAPPDATA "Programs\zaqui-caixa"
$LIMITE_MS = 240000

function Registro {
  Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object { Get-ItemProperty $_.PSPath } |
    Where-Object { $_.DisplayName -like "*Zaqui*" -or $_.DisplayName -like "*Caixa da loja*" } | Select-Object -First 1
}

function Instalar($exe) {
  Write-Host "== instalando $exe (silencioso, limite $($LIMITE_MS/1000) s)"
  $p = Start-Process -FilePath $exe -ArgumentList "/S" -PassThru
  if (-not $p.WaitForExit($LIMITE_MS)) {
    Write-Host "TRAVOU: o instalador nao terminou em $($LIMITE_MS/1000) s"
    Get-Process | Where-Object { $_.ProcessName -match "old-uninstaller|Uninstall|Zaqui|instalar" } | Format-Table ProcessName, Id -AutoSize | Out-String | Write-Host
    Get-Process | Where-Object { $_.ProcessName -match "old-uninstaller|Uninstall|Zaqui-Caixa-instalar" } | Stop-Process -Force -ErrorAction SilentlyContinue
    $p | Stop-Process -Force -ErrorAction SilentlyContinue
    return "travou"
  }
  Write-Host "terminou, codigo $($p.ExitCode)"
  Start-Sleep -Seconds 3
  return "codigo $($p.ExitCode)"
}

function Estado($rotulo) {
  $r = Registro
  Write-Host "-- $rotulo"
  Write-Host ("   registro: {0} {1}" -f $r.DisplayName, $r.DisplayVersion)
  Write-Host ("   desinstalar: {0}" -f $r.UninstallString)
  if (Test-Path $pasta) { Get-ChildItem $pasta -Filter *.exe | ForEach-Object { Write-Host "   exe: $($_.Name)" } }
  foreach ($a in @("$env:USERPROFILE\Desktop\Zaqui Caixa.lnk", "$env:USERPROFILE\Desktop\Caixa da loja por Zaqui.lnk", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Zaqui Caixa.lnk", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Caixa da loja por Zaqui.lnk")) {
    if (Test-Path $a) { Write-Host "   atalho: $a" }
  }
  return $r
}

function Fechar {
  Get-Process | Where-Object { $_.ProcessName -match "^(Zaqui Caixa|Caixa da loja por Zaqui)$" } | Stop-Process -Force -ErrorAction SilentlyContinue
}

$antigo = if ($Caso -eq "atualizacao") { "Zaqui-Caixa-instalar-1.1.0.exe" } else { "Zaqui-Caixa-instalar-1.0.0.exe" }
$novo = if ($Caso -eq "controle") { "Zaqui-Caixa-instalar-1.1.0.exe" } else { "Zaqui-Caixa-instalar-1.2.0.exe" }

$r0 = Instalar (Resolve-Path $antigo)
if ($r0 -ne "codigo 0") { throw "a versao antiga nem instalou: $r0" }
$antes = Estado "antes (versao antiga instalada)"
$des = ($antes.UninstallString -replace '^"([^"]+)".*$', '$1')
Write-Host "   integridade do desinstalador instalado: $(node teste/integridade-cli.js $des)"

if ($Caso -eq "corrompido") {
  # Estraga de proposito o desinstalador instalado: troca 64 bytes no meio dos dados do NSIS.
  $b = [IO.File]::ReadAllBytes($des)
  $meio = [int]($b.Length * 0.6)
  for ($i = 0; $i -lt 64; $i++) { $b[$meio + $i] = $b[$meio + $i] -bxor 0x5A }
  [IO.File]::WriteAllBytes($des, $b)
  Write-Host "   desinstalador estragado de proposito; integridade agora: $(node teste/integridade-cli.js $des)"
}

Fechar
$r1 = Instalar (Resolve-Path $novo)
$depois = Estado "depois"
Fechar

$versaoEsperada = if ($Caso -eq "controle") { "1.1.0" } else { "1.2.0" }
$instalou = ($r1 -eq "codigo 0") -and ($depois.DisplayVersion -eq $versaoEsperada) -and (Test-Path (Join-Path $pasta "Caixa da loja por Zaqui.exe"))
if ($Caso -ne "atualizacao") { $instalou = $instalou -and -not (Test-Path (Join-Path $pasta "Zaqui Caixa.exe")) }

if ($Caso -eq "controle") {
  if ($instalou) { throw "CONTROLE: a 1.1.0 instalou por cima da 1.0.0; o teste nao reproduz o defeito" }
  Write-Host "RESULTADO controle: a 1.1.0 NAO instalou por cima da 1.0.0 ($r1), como no laptop. O teste enxerga o defeito."
  exit 0
}
if (-not $instalou) { throw "RESULTADO ${Caso}: a 1.2.0 NAO instalou ($r1, versao $($depois.DisplayVersion))" }
Write-Host "   integridade do desinstalador novo: $(node teste/integridade-cli.js ($depois.UninstallString -replace '^"([^"]+)".*$', '$1'))"

# A proxima atualizacao vai rodar ESTE desinstalador: ele tem de funcionar.
$u = $depois.UninstallString -replace '^"([^"]+)".*$', '$1'
$p = Start-Process -FilePath $u -ArgumentList "/S" -PassThru
if (-not $p.WaitForExit($LIMITE_MS)) { throw "o desinstalador da 1.2.0 travou" }
Start-Sleep -Seconds 3
$fim = Registro
if ($fim) { throw "o desinstalador da 1.2.0 nao tirou o registro" }
Write-Host "RESULTADO ${Caso}: a 1.2.0 instalou ($r1), versao $($depois.DisplayVersion), e o desinstalador dela funciona."
