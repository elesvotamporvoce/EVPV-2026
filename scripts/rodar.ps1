<#
  EVPV — rodar as tarefas do projeto no Windows, sem depender do GitHub Actions.

  Faz o mesmo que o workflow "Rodar tarefa": instala as dependencias, confere a
  conexao com o banco e roda o script escolhido. A diferenca e que aqui a
  DATABASE_URL fica so na sua maquina.

  COMO USAR (PowerShell, dentro da pasta do projeto):
      .\scripts\rodar.ps1                     # abre o menu
      .\scripts\rodar.ps1 -Tarefa tse         # roda direto
      .\scripts\rodar.ps1 -Tarefa licencas -DryRun
      .\scripts\rodar.ps1 -TrocarConexao      # esquece a conexao guardada

  Na primeira vez ele pergunta so a SENHA do banco (digitada mascarada) e monta
  a URL sozinho, ja escapando os caracteres especiais. Isso existe por um
  motivo: uma senha com @ ou / quebra a string de conexao em silencio — o
  driver corta a senha no primeiro @ e o resto da senha vira "endereco do
  banco". Foi isso que produziu o erro "host vazio" no GitHub.
#>

[CmdletBinding()]
param(
  [ValidateSet('menu','licencas','tse','novos_rapido','novos_completo','scores','integridade')]
  [string]$Tarefa = 'menu',
  [switch]$DryRun,
  [switch]$TrocarConexao
)

$ErrorActionPreference = 'Stop'

function Titulo($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }
function Ok($t)     { Write-Host "   $t" -ForegroundColor Green }
function Aviso($t)  { Write-Host "   $t" -ForegroundColor Yellow }
function Erro($t)   { Write-Host "   $t" -ForegroundColor Red }

$HOST_PADRAO = 'db.rvcfbklnwglmhoxfexvj.supabase.co'

# ---------------------------------------------------------------- raiz do repo
# Normalmente o script vive em scripts/, entao a raiz e a pasta de cima. Se
# voce COLAR o conteudo no PowerShell em vez de rodar o arquivo, o
# $PSScriptRoot vem vazio — ai procuramos a raiz subindo da pasta atual.
$Raiz = $null
if ($PSScriptRoot) {
  $c = Split-Path -Parent $PSScriptRoot
  if (Test-Path (Join-Path $c 'ingest\requirements.txt')) { $Raiz = $c }
}
if (-not $Raiz) {
  $d = (Get-Location).Path
  while ($d) {
    if (Test-Path (Join-Path $d 'ingest\requirements.txt')) { $Raiz = $d; break }
    $pai = Split-Path -Parent $d
    if ($pai -eq $d) { break }
    $d = $pai
  }
}
if (-not $Raiz) {
  Erro "Nao achei a pasta do projeto (procurei por ingest\requirements.txt)."
  Erro "Entre na pasta do projeto e rode de novo, por exemplo:"
  Erro "  cd 'C:\Users\diogo\Github\EVPV 2026\EVPV-2026'"
  return
}
Set-Location $Raiz
Ok "Pasta do projeto: $Raiz"

# ------------------------------------------------------------------ 1. Python
Titulo "Python"
$py = $null; $pyPrefix = @()
foreach ($cand in @('py','python','python3')) {
  $cmd = Get-Command $cand -ErrorAction SilentlyContinue
  if (-not $cmd) { continue }
  $pre = if ($cand -eq 'py') { @('-3') } else { @() }
  try {
    $v = & $cmd.Source @pre '--version' 2>&1
    if ($LASTEXITCODE -eq 0) { $py = $cmd.Source; $pyPrefix = $pre; Ok "$v ($py)"; break }
  } catch { }
}
if (-not $py) {
  Erro "Python nao encontrado. Instale em https://www.python.org/downloads/windows/"
  Erro "e marque 'Add python.exe to PATH' na primeira tela do instalador."
  return
}

# ------------------------------------------------------------ 2. dependencias
Titulo "Dependencias"
& $py @pyPrefix -m pip install --quiet --disable-pip-version-check -r ingest\requirements.txt
if ($LASTEXITCODE -ne 0) { Erro "pip install falhou."; return }
Ok "requests e psycopg2 prontos"

# --------------------------------------------------------------- 3. conexao
Titulo "Conexao com o banco"

# A validacao roda em Python com o parse do proprio libpq (parse_dsn), que e o
# que o driver faz de verdade. A string nunca aparece na tela nem na linha de
# comando: vai por variavel de ambiente e sai logo depois.
$CHECAGEM = @'
import os, sys
dsn = os.environ.get("EVPV_TESTE_DSN", "")
def erro(m):
    print("ERRO: " + m); sys.exit(1)
if not dsn.strip():
    erro("string vazia")
if "[YOUR-PASSWORD]" in dsn:
    erro("a string ainda tem [YOUR-PASSWORD]; troque pela senha real")
if not dsn.startswith(("postgresql://", "postgres://")):
    erro("nao comeca com postgresql://")
from psycopg2.extensions import parse_dsn
try:
    p = parse_dsn(dsn)
except Exception as e:
    linha = str(e).strip().splitlines()[0]
    if "percent-encoded" in linha:
        erro("a senha tem um % solto (na URL, % precisa virar %25)")
    erro(linha)
host = p.get("host", "")
if not host:
    erro("sem endereco de banco depois do @")
if "@" in host:
    erro("a senha tem um @ sem escapar: o driver leu o host como '" + host + "'")
if "." not in host:
    erro("o host ficou '" + host + "', que nao parece o endereco do Supabase")
print("formato ok - host %s porta %s usuario %s" % (host, p.get("port", 5432), p.get("user", "?")))
import psycopg2
try:
    c = psycopg2.connect(dsn, connect_timeout=20)
except Exception as e:
    erro("conexao recusada: " + str(e).strip().splitlines()[0])
cur = c.cursor(); cur.execute("select count(*) from person")
print("conexao ok - %d parlamentares no banco" % cur.fetchone()[0])
c.close()
'@

function Testar-Conexao([string]$dsn) {
  $env:EVPV_TESTE_DSN = $dsn
  try {
    $saida = & $py @pyPrefix -c $CHECAGEM 2>&1
    $rc = $LASTEXITCODE
  } finally {
    Remove-Item Env:\EVPV_TESTE_DSN -ErrorAction SilentlyContinue
  }
  return [pscustomobject]@{ ok = ($rc -eq 0); saida = ($saida -join "`n") }
}

function Ler-SenhaComoTexto([string]$prompt) {
  $seg = Read-Host -AsSecureString $prompt
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seg)
  try   { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

$dsn = $null
if (-not $TrocarConexao) { $dsn = $env:DATABASE_URL }

if ($dsn) {
  Ok "Usando a DATABASE_URL que ja esta no ambiente"
} else {
  Write-Host "   1) Digitar so a senha do banco (recomendado — eu monto a URL e escapo tudo)"
  Write-Host "   2) Colar a URI inteira que copiei do Supabase"
  $modo = (Read-Host "   Opcao [1]").Trim()
  if ($modo -eq '') { $modo = '1' }

  if ($modo -eq '1') {
    $h = (Read-Host "   Host do banco [$HOST_PADRAO]").Trim()
    if ($h -eq '') { $h = $HOST_PADRAO }
    $u = (Read-Host "   Usuario [postgres]").Trim()
    if ($u -eq '') { $u = 'postgres' }
    $senha = Ler-SenhaComoTexto "   Senha do banco (nao aparece na tela)"
    if (-not $senha) { Erro "Senha vazia."; return }
    # EscapeDataString transforma @ / : # ? % nos codigos %40 %2F etc.
    $senhaEsc = [uri]::EscapeDataString($senha)
    $dsn = "postgresql://$([uri]::EscapeDataString($u)):$senhaEsc@${h}:5432/postgres"
    if ($senhaEsc -ne $senha) {
      Aviso "Sua senha tem caractere especial — escapei na URL (e por isso que colar a mao dava erro)."
    }
  } else {
    $dsn = (Ler-SenhaComoTexto "   Cole a URI inteira (nao aparece na tela)").Trim().Trim('"').Trim("'")
  }
}

$r = Testar-Conexao $dsn
Write-Host ($r.saida -replace '(?m)^', '   ')
if (-not $r.ok) {
  Write-Host ""
  Erro "Nao deu. Rode de novo com -TrocarConexao e escolha a opcao 1,"
  Erro "que monta a URL a partir da senha e evita esse tipo de erro."
  return
}
$env:DATABASE_URL = $dsn

if (-not [Environment]::GetEnvironmentVariable('DATABASE_URL','User')) {
  $g = (Read-Host "   Guardar essa conexao para as proximas vezes? (s/n)").Trim()
  if ($g -match '^[sSyY]') {
    [Environment]::SetEnvironmentVariable('DATABASE_URL', $dsn, 'User')
    Ok "Guardada no seu usuario. Para apagar depois, rode:"
    Ok '  [Environment]::SetEnvironmentVariable(''DATABASE_URL'', $null, ''User'')'
  }
}

$cb = (Read-Host "   Copiar a string pronta para a area de transferencia (para colar no secret do GitHub)? (s/n)").Trim()
if ($cb -match '^[sSyY]') {
  Set-Clipboard -Value $dsn
  Ok "Copiada. Cole em GitHub > Settings > Secrets and variables > Actions > DATABASE_URL."
  Aviso "Ela esta na area de transferencia: copie outra coisa depois para nao deixar a senha ali."
}

# ------------------------------------------------------------------- 4. tarefa
$opcoes = [ordered]@{
  '1' = @{ id='tse';            texto='TSE: atualiza candidatura dos parlamentares (traz o SEXO -> Candidata)' }
  '2' = @{ id='licencas';       texto='Licencas/afastamentos e recalculo da presenca' }
  '3' = @{ id='novos_rapido';   texto='TSE: candidatos sem historico, sem patrimonio (rapido)' }
  '4' = @{ id='novos_completo'; texto='TSE: candidatos sem historico, com patrimonio (demora)' }
  '5' = @{ id='scores';         texto='Recalcular os scores' }
  '6' = @{ id='integridade';    texto='Checagem de integridade dos dados' }
}

if ($Tarefa -eq 'menu') {
  Titulo "O que voce quer rodar?"
  foreach ($k in $opcoes.Keys) { Write-Host "   $k) $($opcoes[$k].texto)" }
  $esc = (Read-Host "   Numero").Trim()
  if (-not $opcoes.Contains($esc)) { Erro "Opcao invalida."; return }
  $Tarefa = $opcoes[$esc].id
}

$comandos = @{
  'tse'            = @('scripts\ingest_tse_2026.py')
  'novos_rapido'   = @('scripts\ingest_candidatos_novos.py','--sem-bens')
  'novos_completo' = @('scripts\ingest_candidatos_novos.py')
  'scores'         = @('scoring\score.py')
  'integridade'    = @('scripts\check_integrity.py')
  'licencas'       = @('scripts\update_afastamentos.py')
}
$cmd = @($comandos[$Tarefa])
if ($DryRun -and $Tarefa -eq 'licencas') { $cmd += '--dry-run' }

Titulo "Rodando: $Tarefa"
Write-Host "   (pode levar alguns minutos; a API do TSE e lenta)" -ForegroundColor DarkGray
& $py @pyPrefix @cmd
$saiu = $LASTEXITCODE

Titulo "Resultado"
if ($saiu -ne 0) { Erro "A tarefa terminou com erro (codigo $saiu)."; return }
Ok "Tarefa concluida."

# ----------------------------------------------------- 5. derrubar o cache
if ($env:REVALIDATE_SECRET) {
  try {
    Invoke-RestMethod -Uri "https://www.elesvotamporvoce.org/api/revalidate?secret=$($env:REVALIDATE_SECRET)" -TimeoutSec 30 | Out-Null
    Ok "Cache do site derrubado."
  } catch {
    Aviso "Nao consegui chamar o revalidate; o cache expira sozinho em ate 15 min."
  }
} else {
  Aviso "REVALIDATE_SECRET nao esta no ambiente: o cache do site expira sozinho em ate 15 min."
}
