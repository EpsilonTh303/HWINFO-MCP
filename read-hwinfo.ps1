param([string]$OutputPath = "$PSScriptRoot\hwinfo-sensors.json")
$ErrorActionPreference = 'Stop'
$map = [IO.MemoryMappedFiles.MemoryMappedFile]::OpenExisting('Global\HWiNFO_SENS_SM2', [IO.MemoryMappedFiles.MemoryMappedFileRights]::Read)
$mutex = $null
$locked = $false
try {
  $mutex = [Threading.Mutex]::OpenExisting('Global\HWiNFO_SM2_MUTEX')
  $locked = $mutex.WaitOne(3000)
  if (!$locked) { throw 'HWiNFO sensor snapshot is busy.' }
  $view = $map.CreateViewAccessor(0, 0, [IO.MemoryMappedFiles.MemoryMappedFileAccess]::Read)
  try {
    if ($view.ReadUInt32(0) -ne 0x53695748) { throw 'HWiNFO shared memory is not active.' }
    $sensorOffset = $view.ReadUInt32(20); $sensorSize = $view.ReadUInt32(24); $sensorCount = $view.ReadUInt32(28)
    $readingOffset = $view.ReadUInt32(32); $readingSize = $view.ReadUInt32(36); $readingCount = $view.ReadUInt32(40)
    if ($sensorCount -gt 10000 -or $readingCount -gt 100000 -or $sensorSize -lt 264 -or $readingSize -lt 316) { throw 'Unsupported shared memory layout.' }
    function Read-Label([long]$Offset, [int]$Length) {
      $bytes = New-Object byte[] $Length
      $null = $view.ReadArray($Offset, $bytes, 0, $Length)
      return [Text.Encoding]::Default.GetString($bytes).Split([char]0)[0]
    }
    $names = for ($i=0; $i -lt $sensorCount; $i++) { Read-Label ($sensorOffset + $i*$sensorSize + 136) 128 }
    $readings = for ($i=0; $i -lt $readingCount; $i++) {
      $offset = [long]$readingOffset + $i*$readingSize
      $index = $view.ReadUInt32($offset+4)
      if ($index -ge $sensorCount) { throw 'Invalid sensor index.' }
      [pscustomobject]@{
        Sensor=$names[$index]; Name=(Read-Label ($offset+140) 128); Unit=(Read-Label ($offset+268) 16)
        Current=$view.ReadDouble($offset+284); Minimum=$view.ReadDouble($offset+292)
        Maximum=$view.ReadDouble($offset+300); Average=$view.ReadDouble($offset+308)
      }
    }
    [pscustomobject]@{CapturedAt=(Get-Date).ToString('o'); PollUnixTime=$view.ReadInt64(12); Readings=@($readings)} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding utf8
    Write-Output "Read $readingCount values into $OutputPath"
  } finally { $view.Dispose() }
} finally {
  if ($locked) { $mutex.ReleaseMutex() }
  if ($mutex) { $mutex.Dispose() }
  $map.Dispose()
}
