$ErrorActionPreference = 'Stop'
$setup = Start-Process -FilePath "$PWD\installer\AutoEdit-0.1.0-win-x64.exe" -ArgumentList '/S' -Wait -PassThru
if ($setup.ExitCode -notin @(0,3010)) { throw "Installer failed: $($setup.ExitCode)" }
$appRoot = Join-Path $env:ProgramFiles 'AutoEdit'
if (!(Test-Path "$appRoot\AutoEdit.exe")) { throw 'Installed app not found' }
$toolRoot = "$appRoot\resources\tools"
& "$toolRoot\ffmpeg.exe" -v error -y -f lavfi -i 'color=c=blue:s=320x240:r=24:d=3' -f lavfi -i 'sine=frequency=440:sample_rate=16000:duration=3' -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest probe.mp4
if ($LASTEXITCODE -ne 0) { throw 'Video encoding failed' }
& "$toolRoot\ffprobe.exe" -v error -show_entries format=duration -of json probe.mp4 | Out-File media.log
if ($LASTEXITCODE -ne 0) { throw 'Video reading failed' }
& "$toolRoot\ffmpeg.exe" -v error -y -i probe.mp4 -vn -ar 16000 -ac 1 probe.wav
& "$toolRoot\whisper-cli.exe" -m "$appRoot\resources\models\ggml-large-v3-turbo.bin" -f "$PWD\probe.wav" -l ko -ng -nt *> speech.log
if ($LASTEXITCODE -ne 0) { throw 'Speech model failed to load' }
$env:CAPCUT_DEBUG_PLAYTEST = 'distribution'
$env:CAPCUT_CREATOR_MODE = '1'
$env:CAPCUT_DEBUG_PUBLIC = '1'
$env:OPENAI_API_KEY = $null
$env:GH_TOKEN = $null
$appProcess = Start-Process -FilePath "$appRoot\AutoEdit.exe" -PassThru -RedirectStandardOutput "$PWD\app.log" -RedirectStandardError "$PWD\app-error.log"
$passed = $false
for ($attempt = 0; $attempt -lt 90; $attempt++) {
  Start-Sleep -Seconds 1
  if ((Test-Path app.log) -and ((Get-Content app.log -Raw) -match 'PASS:')) { $passed=$true; break }
  if ($appProcess.HasExited) { break }
}
if (!$appProcess.HasExited) { taskkill /pid $appProcess.Id /T /F | Out-Null }
if (!$passed) { throw 'Installed app startup check failed' }
'PASS: Windows installation, MP4 creation, speech model, bundled fonts and public permissions' | Tee-Object -FilePath result.log
