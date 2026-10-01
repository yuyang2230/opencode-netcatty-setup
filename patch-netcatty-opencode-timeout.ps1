# Patch Netcatty app.asar: raise embedded @opencode-ai/sdk createOpencodeServer
# startup timeout from 5000ms to 64000ms (byte-length-preserving replace).
#
# Why: on Windows the opencode server cold start takes 4.6~8.9s, so the SDK
# default 5000ms deadline fails with "Timeout waiting for server to start
# after 5000ms". See https://github.com/binaricat/Netcatty/issues/3578
#
# CAUTION: app.asar contains 8 occurrences of "timeout: 5000". Only the 2
# right after "port: 4096," belong to the opencode SDK (server.js / v2/server.js).
# The other 6 belong to gh/wsl/ssh-add/icacls features and MUST NOT be touched.
# This script anchors on "port: 4096," for exact matching.
#
# Usage: run in an elevated PowerShell, Netcatty fully closed first.
# Note: a Netcatty upgrade overwrites app.asar -- re-apply if the issue returns.

$asar = 'C:\Program Files\Netcatty\resources\app.asar'
if (-not (Test-Path $asar)) { $asar = "$env:LOCALAPPDATA\Programs\Netcatty\resources\app.asar" }
if (-not (Test-Path $asar)) { throw "app.asar not found. Edit `$asar in this script." }

$bak = "$asar.bak-timeout5000"
Copy-Item $asar $bak -Force

# Latin-1 (28591) keeps a strict 1 byte = 1 char mapping, so the file length
# is preserved and the asar index stays valid.
$enc = [Text.Encoding]::GetEncoding(28591)
$s = [IO.File]::ReadAllText($asar, $enc)
$n = [regex]::Matches($s, '(port: 4096,(\s+)timeout: )5000,').Count
if ($n -eq 0) { throw "No anchor matched (already patched, or Netcatty version changed the layout)." }
$s = [regex]::Replace($s, '(port: 4096,(\s+)timeout: )5000,', '${1}64e3,')
[IO.File]::WriteAllText($asar, $s, $enc)
"Patched $n place(s) (expected 2). Backup: $bak"
