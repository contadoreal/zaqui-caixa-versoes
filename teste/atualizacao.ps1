# TESTE DA ATUALIZAÇÃO SOZINHA DO CAIXA NUM WINDOWS LIMPO (versão 1.2.1, pedido do Pedro, 13/11/2026).
# Um servidor local faz de "GitHub" (latest.yml e o instalador) e de "portal" (uma página que fala com o
# programa como a do caixa: conta a atividade e, no caso "toque", toca em Reiniciar agora).
# Uso: atualizacao.ps1 -Caso <toque120|x120|x121|madrugada121|segura121|abertura121>
param([string]$Caso)
$ErrorActionPreference = "Stop"
$pasta = Join-Path $env:LOCALAPPDATA "Programs\zaqui-caixa"
$exe = Join-Path $pasta "Caixa da loja por Zaqui.exe"
$atalho = Join-Path ([Environment]::GetFolderPath("Desktop")) "Caixa da loja por Zaqui.lnk"
$pendente = Join-Path $env:LOCALAPPDATA "zaqui-caixa-updater\pending"
$de = if ($Caso -like "*120") { "1.2.0" } else { "1.2.1" }
$para = if ($Caso -like "*120") { "1.2.1" } else { "1.2.2" }

function Registro {
  Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object { Get-ItemProperty $_.PSPath } |
    Where-Object { $_.DisplayName -like "*Caixa da loja*" -or $_.DisplayName -like "*Zaqui*" } | Select-Object -First 1
}
function Programa { Get-Process -Name "Caixa da loja por Zaqui" -ErrorAction SilentlyContinue }
function Diagnostico {
  Write-Host "---- diagnostico"
  Write-Host "   registro: $((Registro).DisplayVersion)"
  Get-ChildItem (Join-Path $env:LOCALAPPDATA "zaqui-caixa-updater") -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "   cache: $($_.FullName) $($_.Length)" }
  Programa | ForEach-Object { Write-Host "   processo $($_.Id) desde $($_.StartTime)" }
  $reg = Join-Path $env:APPDATA "Zaqui Caixa\registro.log"
  if (Test-Path $reg) { Write-Host "   ---- registro.log do programa"; Get-Content $reg -Tail 80 | ForEach-Object { Write-Host "   | $_" } }
  foreach ($f in @("programa-saida.txt", "programa-erro.txt", "programa-saida2.txt", "programa-erro2.txt")) { if (Test-Path $f) { Write-Host "   ---- $f"; Get-Content $f -Tail 60 | ForEach-Object { Write-Host "   | $_" } } }
}
function Falhar($msg) { Diagnostico; throw $msg }
function Esperar($o, $limite, [scriptblock]$cond) {
  $t = [Diagnostics.Stopwatch]::StartNew()
  while ($t.Elapsed.TotalSeconds -lt $limite) { if (& $cond) { Write-Host "   $o em $([int]$t.Elapsed.TotalSeconds) s"; return $true }; Start-Sleep -Seconds 2 }
  Write-Host "   ${o}: NAO em $limite s"; return $false
}

# O "GitHub" e o "portal" locais.
New-Item -ItemType Directory -Force feed\lojista\caixa | Out-Null
Copy-Item "Zaqui-Caixa-instalar-$para.exe", "Zaqui-Caixa-instalar-$para.exe.blockmap" feed\
Copy-Item "latest-$para.yml" feed\latest.yml
$modo = switch ($Caso) { "toque120" { "toque" } "segura121" { "segura" } default { "livre" } }
@"
<!doctype html><meta charset="utf-8"><title>caixa de teste</title><body>caixa de teste ($modo)
<script>
const z = window.zaquiCaixa;
setInterval(async () => {
  if (!z) return;
  if (z.informarAtividade) z.informarAtividade({ novos: "$modo" === "segura" ? 1 : 0, ultimaAtividadeEm: null });
  if ("$modo" === "toque") { const e = await z.estado(); if (e && e.atualizacao) z.instalarAtualizacao(); }
}, 3000);
</script>
"@ | Set-Content -Encoding utf8 feed\lojista\caixa\index.html
Start-Process python -ArgumentList "-m", "http.server", "8080", "--directory", "feed" -WindowStyle Hidden

# A versão de partida instalada, apontada para o servidor local, com os ajustes já feitos (sem a tela de Ajustes).
$p = Start-Process (Resolve-Path "Zaqui-Caixa-instalar-$de.exe") -ArgumentList "/S" -PassThru
if (-not $p.WaitForExit(240000)) { throw "a $de nao instalou" }
Start-Sleep 3
Get-Process -Name "Caixa da loja por Zaqui" -ErrorAction SilentlyContinue | Stop-Process -Force
"provider: generic`nurl: http://localhost:8080/`nupdaterCacheDirName: zaqui-caixa-updater`n" | Set-Content -Encoding ascii (Join-Path $pasta "resources\app-update.yml")
$dados = Join-Path $env:APPDATA "Zaqui Caixa"
New-Item -ItemType Directory -Force $dados | Out-Null
'{"desde":"2026-11-13T00:00:00.000Z","sozinho":{"caixa":false,"cozinha":false},"whatsapp":"web"}' | Set-Content -Encoding ascii (Join-Path $dados "ajustes.json")
# O atalho apagado de propósito (como ficou no laptop do Pedro): a atualização tem de recriá-lo.
if ($Caso -in @("toque120", "x121")) { Remove-Item $atalho -ErrorAction SilentlyContinue; Write-Host "   atalho apagado antes: $(-not (Test-Path $atalho))" }

$env:ZAQUI_CAIXA_URL = "http://localhost:8080"
if ($Caso -in @("madrugada121", "segura121")) { $env:ZAQUI_CAIXA_MADRUGADA_TESTE = "1"; $env:ZAQUI_CAIXA_MADRUGADA_INTERVALO_MS = "15000" }
Write-Host "== $Caso : $de instalada; abrindo o programa"
Start-Process $exe -RedirectStandardOutput programa-saida.txt -RedirectStandardError programa-erro.txt
if (-not (Esperar "programa aberto" 60 { Programa })) { Falhar "o programa $de nao abriu" }
if (-not (Esperar "versao $para baixada" 240 { Test-Path (Join-Path $pendente "Zaqui-Caixa-instalar-$para.exe") })) { Falhar "a $para nao baixou" }
Start-Sleep 5

switch ($Caso) {
  { $_ -in @("x120", "x121") } { Write-Host "== fechando no X"; (Programa | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1).CloseMainWindow() | Out-Null }
  "abertura121" {
    Write-Host "== programa morto sem fechar (como o computador desligado) e aberto de novo"
    Programa | Stop-Process -Force; Start-Sleep 3; Start-Process $exe -RedirectStandardOutput programa-saida2.txt -RedirectStandardError programa-erro2.txt
  }
}

$instalou = Esperar "registro na $para" 300 { (Registro).DisplayVersion -eq $para }
if ($Caso -eq "segura121") {
  if ($instalou) { Falhar "SEGURA: instalou com pedido novo esperando" }
  Write-Host "RESULTADO segura121: com pedido novo esperando, a madrugada NAO instalou em 5 min (versao $((Registro).DisplayVersion))."
  exit 0
}
if (-not $instalou) {
  if ($Caso -eq "x120") { Write-Host "RESULTADO x120 (diagnostico da 1.2.0): fechar no X NAO instalou a $para em 5 min, como o Pedro viu."; exit 0 }
  Falhar "RESULTADO ${Caso}: a $para NAO instalou"
}
# O instalador fecha qualquer programa aberto antes de copiar: programa aberto DEPOIS que ele termina foi reaberto.
$reabriu = Esperar "instalador terminou e o programa reabriu" 120 { -not (Get-Process -Name "Zaqui-Caixa-instalar*" -ErrorAction SilentlyContinue) -and (Programa) }
$sh = (New-Object -ComObject WScript.Shell).CreateShortcut($atalho)
Write-Host "   atalho: existe=$(Test-Path $atalho) alvo=$($sh.TargetPath) alvo_existe=$(Test-Path $sh.TargetPath)"
$atalhoOk = (Test-Path $atalho) -and ($sh.TargetPath -eq $exe) -and (Test-Path $exe)
if ($Caso -eq "x120") { Write-Host "RESULTADO x120 (diagnostico da 1.2.0): fechar no X instalou a $para; reabriu=$reabriu; atalho=$atalhoOk"; exit 0 }
if (-not $reabriu) { Falhar "RESULTADO ${Caso}: instalou a $para mas o programa NAO reabriu" }
if (-not $atalhoOk) { Falhar "RESULTADO ${Caso}: instalou e reabriu, mas o atalho da area de trabalho nao esta certo" }
Write-Host "RESULTADO ${Caso}: a $para instalou sozinha, o programa reabriu e o atalho aponta para o exe."
Diagnostico
