# PowerShell script to run MAC unit performance test

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "MAC Unit Performance Test" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Compile
Write-Host "Compiling..." -ForegroundColor Yellow
iverilog -g2012 -o mac_perf_sim.exe rtl/mac_unit.sv tb/tb_mac_performance.sv

if ($LASTEXITCODE -ne 0) {
    Write-Host "Compilation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Compilation successful!" -ForegroundColor Green
Write-Host ""

# Run simulation
Write-Host "Running simulation..." -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
vvp mac_perf_sim.exe

# Check result
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Simulation completed successfully" -ForegroundColor Green
    
    # Check if waveform was generated
    if (Test-Path "mac_performance.fst") {
        Write-Host "Waveform saved to: mac_performance.fst" -ForegroundColor Green
        Write-Host "View with: gtkwave mac_performance.fst" -ForegroundColor Cyan
    }
} else {
    Write-Host ""
    Write-Host "Simulation failed!" -ForegroundColor Red
    exit 1
}
