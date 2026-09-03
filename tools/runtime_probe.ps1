param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 33335,
    [int]$Samples = 10,
    [int]$IntervalMs = 300
)

$ErrorActionPreference = "Stop"

$script:IAC  = 255
$script:DONT = 254
$script:DO   = 253
$script:WONT = 252
$script:WILL = 251
$script:SB   = 250
$script:SE   = 240

function Send-TelnetReply {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,
        [int]$Command,
        [int]$Option
    )

    $supported = $Option -in @(0,1,3)
    switch($Command) {
        253 { $reply = $(if($supported){251}else{252}) } # DO -> WILL/WONT
        254 { $reply = 252 }                            # DONT -> WONT
        251 { $reply = $(if($supported){253}else{254}) } # WILL -> DO/DONT
        252 { $reply = 254 }                            # WONT -> DONT
        default { return }
    }

    [byte[]]$bytes = @($script:IAC, $reply, $Option)
    $Stream.Write($bytes, 0, $bytes.Length)
    $Stream.Flush()
}

function Read-Telnet {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,
        [int]$FirstWaitMs = 20,
        [int]$IdleMs = 20,
        [int]$MaxMs = 1000
    )

    if($FirstWaitMs -gt 0) { Start-Sleep -Milliseconds $FirstWaitMs }

    $text = New-Object System.Text.StringBuilder
    $buffer = New-Object byte[] 8192
    $state = "data"
    $pendingCommand = 0
    $gotAny = $false
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $lastData = 0

    while($sw.ElapsedMilliseconds -lt $MaxMs) {
        while($Stream.DataAvailable) {
            $n = $Stream.Read($buffer, 0, $buffer.Length)
            if($n -le 0) { break }
            $gotAny = $true
            $lastData = $sw.ElapsedMilliseconds

            for($i = 0; $i -lt $n; $i++) {
                $b = [int]$buffer[$i]

                switch($state) {
                    "data" {
                        if($b -eq $script:IAC) {
                            $state = "iac"
                        } else {
                            [void]$text.Append([char]$b)
                        }
                    }
                    "iac" {
                        if($b -eq $script:IAC) {
                            [void]$text.Append([char]$b)
                            $state = "data"
                        } elseif($b -in @($script:DO,$script:DONT,$script:WILL,$script:WONT)) {
                            $pendingCommand = $b
                            $state = "option"
                        } elseif($b -eq $script:SB) {
                            $state = "sub"
                        } else {
                            $state = "data"
                        }
                    }
                    "option" {
                        Send-TelnetReply -Stream $Stream -Command $pendingCommand -Option $b
                        $pendingCommand = 0
                        $state = "data"
                    }
                    "sub" {
                        if($b -eq $script:IAC) { $state = "subiac" }
                    }
                    "subiac" {
                        if($b -eq $script:SE) { $state = "data" }
                        elseif($b -ne $script:IAC) { $state = "sub" }
                    }
                }
            }
        }

        if($gotAny -and (($sw.ElapsedMilliseconds - $lastData) -ge $IdleMs)) { break }
        Start-Sleep -Milliseconds 5
    }

    $s = $text.ToString()
    $s = [regex]::Replace($s, "\x1B\[[0-9;?]*[ -/]*[@-~]", "")
    return $s
}

function Invoke-Renode {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,
        [string]$Command
    )

    [void](Read-Telnet -Stream $Stream -FirstWaitMs 0 -IdleMs 5 -MaxMs 30)

    [byte[]]$line = [Text.Encoding]::ASCII.GetBytes($Command + "`r`n")
    $Stream.Write($line, 0, $line.Length)
    $Stream.Flush()

    return (Read-Telnet -Stream $Stream -FirstWaitMs 15 -IdleMs 25 -MaxMs 800).Trim()
}

Write-Host "=== VirtualSTM32 Runtime Probe v2 (Telnet-aware) ===" -ForegroundColor Cyan
Write-Host "Target monitor: ${HostName}:$Port"
Write-Host ""

$client = [System.Net.Sockets.TcpClient]::new()
try {
    $client.Connect($HostName, $Port)
} catch {
    Write-Host "[FAIL] Could not connect to Renode Monitor." -ForegroundColor Red
    exit 2
}

$stream = $client.GetStream()

try {
    $greeting = Read-Telnet -Stream $stream -FirstWaitMs 50 -IdleMs 30 -MaxMs 1500
    if([string]::IsNullOrWhiteSpace($greeting)) {
        Write-Host "[FAIL] TCP connected, but no Telnet Monitor greeting was received." -ForegroundColor Red
        exit 3
    }

    Write-Host "[ OK ] Telnet Monitor negotiation completed." -ForegroundColor Green
    Write-Host (($greeting -replace "`r","" -replace "`n"," | ").Trim())

    Write-Host ""
    Write-Host "--- Initial state ---" -ForegroundColor Yellow

    $commands = @(
        "sysbus.cpu PC",
        'sysbus FindSymbolAt `sysbus.cpu PC`',
        "gpioPortC.led0 State",
        "sysbus ReadDoubleWord 0x40011004",
        "sysbus ReadDoubleWord 0x4001100C"
    )

    foreach($cmd in $commands) {
        $r = Invoke-Renode -Stream $stream -Command $cmd
        Write-Host "> $cmd"
        if([string]::IsNullOrWhiteSpace($r)) {
            Write-Host "  <no response>" -ForegroundColor Red
        } else {
            ($r -replace "`r","").Split("`n") | ForEach-Object {
                if($_.Trim().Length -gt 0) { Write-Host "  $_" }
            }
        }
    }

    Write-Host ""
    Write-Host "--- Live samples ---" -ForegroundColor Yellow

    for($i = 1; $i -le $Samples; $i++) {
        $pc     = (Invoke-Renode -Stream $stream -Command "sysbus.cpu PC") -replace "\s+"," "
        $symbol = (Invoke-Renode -Stream $stream -Command 'sysbus FindSymbolAt `sysbus.cpu PC`') -replace "\s+"," "
        $led    = (Invoke-Renode -Stream $stream -Command "gpioPortC.led0 State") -replace "\s+"," "
        $odr    = (Invoke-Renode -Stream $stream -Command "sysbus ReadDoubleWord 0x4001100C") -replace "\s+"," "

        Write-Host ("[{0,2}] PC={1} | symbol={2} | LED0={3} | ODR={4}" -f `
            $i,$pc.Trim(),$symbol.Trim(),$led.Trim(),$odr.Trim())

        Start-Sleep -Milliseconds $IntervalMs
    }

    Write-Host ""
    Write-Host "Copy the complete output back to ChatGPT if LED0 still does not flash." -ForegroundColor Green
}
finally {
    $stream.Dispose()
    $client.Close()
}
