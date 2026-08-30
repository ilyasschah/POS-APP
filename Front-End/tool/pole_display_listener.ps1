<#
.SYNOPSIS
  A fake VFD pole display. Listens on a COM port and draws whatever the POS
  writes to it, exactly as a real 2-line display would.

.DESCRIPTION
  Pair this with com0com so you can test the customer display with no hardware:
  com0com joins two ports back to back, the POS writes to one end, this script
  reads the other and renders it.

      [ POS APP ] --> COM8  ~~com0com~~  COM9 <-- [ this script ]

  It decodes the same protocol receipt_printer_service writes:
    0x0C  form feed   -> clear the display
    text            -> padded/trimmed to the configured character width
    0x0D  carriage return -> end of line

  So a correct POS write shows up here as two lines of exactly NumChars
  characters. If nothing appears at all, the POS is writing to a different port
  than the one you paired -- which is the whole class of bug this exists to make
  visible.

.PARAMETER Port
  The port THIS SCRIPT listens on -- the far end of the pair. Not the port you
  set in the POS.

.PARAMETER Width
  Characters per line. Must match Settings -> Customer Display -> number of
  characters (default 20), or the padding will look wrong and you will chase a
  bug that is not there.

.PARAMETER SelfTest
  Decodes a synthetic frame instead of opening a port, and checks the two lines
  came out right. Proves the script works before you go looking for a wiring
  fault that is really a bug in here.

.PARAMETER Charset
  How to DECODE what arrives. Must match Settings -> Customer Display ->
  character set. Get this wrong and Arabic renders as unrelated Latin letters,
  which looks exactly like the POS bug you are trying to confirm is fixed.

.EXAMPLE
  .\pole_display_listener.ps1 -SelfTest
  .\pole_display_listener.ps1 -Port COM9
  .\pole_display_listener.ps1 -Port COM9 -Width 20 -BaudRate 9600
#>
[CmdletBinding(DefaultParameterSetName = 'Listen')]
param(
  [Parameter(Mandatory = $true, ParameterSetName = 'Listen')][string]$Port,
  [Parameter(Mandatory = $true, ParameterSetName = 'SelfTest')][switch]$SelfTest,
  [int]$BaudRate = 9600,
  [int]$Width = 20,
  [ValidateSet('None', 'Odd', 'Even', 'Mark', 'Space')][string]$Parity = 'None',
  [int]$DataBits = 8,
  [ValidateSet('One', 'Two', 'OnePointFive')][string]$StopBits = 'One',
  # Which codepage to DECODE with. Must match Settings -> Customer Display ->
  # character set, or Arabic arrives as unrelated Latin letters and you chase a
  # bug that is only in this script.
  [ValidateSet('ascii', 'latin1', 'cp1256')][string]$Charset = 'ascii'
)

$ErrorActionPreference = 'Stop'

# The decoder, kept apart from the serial plumbing so -SelfTest can drive it.
# $State is a hashtable: Line1, Line2, Buffer, LineIndex, Writes.
function Update-DisplayState {
  param([hashtable]$State, [string]$Chunk)
  foreach ($ch in $Chunk.ToCharArray()) {
    switch ([int]$ch) {
      12 {
        # form feed - a new write begins, clear both lines
        $State.Line1 = ''; $State.Line2 = ''
        $State.LineIndex = 0; $State.Buffer = ''
        $State.Writes++
      }
      13 {
        # carriage return - commit the line we were filling
        if ($State.LineIndex -eq 0) { $State.Line1 = $State.Buffer }
        else { $State.Line2 = $State.Buffer }
        $State.Buffer = ''
        $State.LineIndex++
      }
      10 { }   # ignore a stray LF
      default {
        # A byte over 0x7F means the POS sent something outside ASCII. If
        # this script is decoding Latin-1 it will render that as unrelated
        # letters - the exact garbage the charset work exists to avoid -
        # so count them and say so rather than letting it look like a bug
        # in the POS.
        if ([int]$ch -ge 0x80) { $State.HighBytes++ }
        $State.Buffer += $ch
      }
    }
  }
  return $State
}

function New-DisplayState {
  return @{ Line1 = ''; Line2 = ''; Buffer = ''; LineIndex = 0; Writes = 0; HighBytes = 0 }
}

if ($SelfTest) {
  # Exactly what CustomerDisplayService._send writes:
  #   0x0C + line1 padded to Width + 0x0D + line2 padded to Width + 0x0D
  $w = $Width
  $l1 = 'TOTAL DUE'.PadRight($w)
  $l2 = 'MAD 42.50'.PadRight($w)
  $frame = [string][char]12 + $l1 + [char]13 + $l2 + [char]13

  $s = New-DisplayState
  # Feed it in two chunks, because a serial read splits wherever it likes and a
  # decoder that only works on a whole frame would pass a test and fail a till.
  $s = Update-DisplayState -State $s -Chunk $frame.Substring(0, 7)
  $s = Update-DisplayState -State $s -Chunk $frame.Substring(7)

  $ok = $true
  if ($s.Line1 -ne $l1) { Write-Host "FAIL line1: '$($s.Line1)'" -ForegroundColor Red; $ok = $false }
  if ($s.Line2 -ne $l2) { Write-Host "FAIL line2: '$($s.Line2)'" -ForegroundColor Red; $ok = $false }
  if ($s.Writes -ne 1) { Write-Host "FAIL writes: $($s.Writes)" -ForegroundColor Red; $ok = $false }

  # A second write must REPLACE the first, not append to it.
  $s = Update-DisplayState -State $s -Chunk ([string][char]12 + 'WELCOME!'.PadRight($w) + [char]13)
  if ($s.Line1 -ne 'WELCOME!'.PadRight($w)) { Write-Host "FAIL redraw: '$($s.Line1)'" -ForegroundColor Red; $ok = $false }
  if ($s.Line2 -ne '') { Write-Host "FAIL stale line2: '$($s.Line2)'" -ForegroundColor Red; $ok = $false }

  if ($ok) {
    Write-Host "Self-test passed - the decoder reads what the POS writes." -ForegroundColor Green
    Write-Host ("  line 1: [{0}]" -f $l1)
    Write-Host ("  line 2: [{0}]" -f $l2)
    exit 0
  }
  exit 1
}

$present = [System.IO.Ports.SerialPort]::GetPortNames()
if ($present -notcontains $Port) {
  Write-Host "This machine has no $Port." -ForegroundColor Red
  if ($present.Count -eq 0) {
    Write-Host "It reports no serial port at all. Create a pair with com0com first (see below)." -ForegroundColor Yellow
  } else {
    Write-Host ("Ports it does have: {0}" -f ($present -join ', ')) -ForegroundColor Yellow
  }
  Write-Host ""
  Write-Host "To make a virtual pair (elevated prompt):" -ForegroundColor Cyan
  Write-Host '  cd "C:\Program Files (x86)\com0com"'
  Write-Host '  .\setupc.exe install PortName=COM8 PortName=COM9'
  Write-Host ""
  Write-Host "Then set the POS to COM8 and run:  .\pole_display_listener.ps1 -Port COM9"
  exit 1
}

$sp = New-Object System.IO.Ports.SerialPort $Port, $BaudRate, $Parity, $DataBits, $StopBits
$sp.ReadTimeout = 500
# The POS writes raw bytes, form feed included; read them as bytes, not text.
$codepage = if ($Charset -eq 'cp1256') { 1256 } else { 28591 }
$sp.Encoding = [System.Text.Encoding]::GetEncoding($codepage)

try {
  $sp.Open()
} catch {
  Write-Host "Could not open $Port : $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Something else is probably holding it open - close any terminal or other listener." -ForegroundColor Yellow
  exit 1
}

$state = New-DisplayState

function Show-Display {
  param([string]$L1, [string]$L2, [int]$W, [int]$Writes, [int]$HighBytes = 0)
  Clear-Host
  Write-Host ""
  Write-Host "  VIRTUAL POLE DISPLAY   $Port @ $BaudRate   ${W} chars   $Charset   writes: $Writes" -ForegroundColor DarkGray
  Write-Host ""
  Write-Host ("  +" + ("-" * ($W + 2)) + "+") -ForegroundColor DarkCyan
  Write-Host ("  | " + $L1.PadRight($W).Substring(0, $W) + " |") -ForegroundColor Green
  Write-Host ("  | " + $L2.PadRight($W).Substring(0, $W) + " |") -ForegroundColor Green
  Write-Host ("  +" + ("-" * ($W + 2)) + "+") -ForegroundColor DarkCyan
  Write-Host ""
  if ($Charset -ne 'cp1256' -and $HighBytes -gt 0) {
    Write-Host "  $HighBytes non-ASCII bytes arrived and THIS SCRIPT is decoding as Latin-1." -ForegroundColor Yellow
    Write-Host "  If the text above looks like garbage, that is the decoder, not the POS." -ForegroundColor Yellow
    Write-Host "  Restart with:  .\pole_display_listener.ps1 -Port $Port -Charset cp1256" -ForegroundColor Cyan
    Write-Host ""
  }
  if ($Charset -eq 'cp1256') {
    Write-Host "  Note: this terminal does its own right-to-left rendering, so the POS" -ForegroundColor DarkGray
    Write-Host "  setting 'Arabic, reversed' will read BACKWARDS here. That is expected -" -ForegroundColor DarkGray
    Write-Host "  reversed is for a panel that cannot flip on its own. Use plain" -ForegroundColor DarkGray
    Write-Host "  'Arabic (Windows-1256)' while testing against this script." -ForegroundColor DarkGray
    Write-Host ""
  }
  Write-Host "  Ctrl+C to stop." -ForegroundColor DarkGray
}

Show-Display -L1 '' -L2 '' -W $Width -Writes 0 -HighBytes 0

try {
  while ($true) {
    try {
      $chunk = $sp.ReadExisting()
    } catch [TimeoutException] {
      $chunk = ''
    }
    if ([string]::IsNullOrEmpty($chunk)) { Start-Sleep -Milliseconds 60; continue }

    $state = Update-DisplayState -State $state -Chunk $chunk
    Show-Display -L1 $state.Line1 -L2 $state.Line2 -W $Width -Writes $state.Writes -HighBytes $state.HighBytes
  }
} finally {
  $sp.Close()
  $sp.Dispose()
  Write-Host "Closed $Port." -ForegroundColor DarkGray
}
