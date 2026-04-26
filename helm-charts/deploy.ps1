# Helm Deployment Script for QuickHaul
# Usage: .\deploy.ps1 -Environment [prod|dev] [-Service <service-name>]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("prod", "dev")]
    [string]$Environment,
    
    [string]$Service = "all",
    
    [string]$Namespace = "quickhaul-$Environment"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploying QuickHaul to $Environment" -ForegroundColor Cyan
Write-Host "Namespace: $Namespace" -ForegroundColor Cyan
Write-Host "Service: $Service" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Verify namespace exists
$nsExists = kubectl get namespace $Namespace -o name 2>$null
if (-not $nsExists) {
    Write-Host "Creating namespace: $Namespace" -ForegroundColor Yellow
    kubectl apply -f templates/namespace-$Environment.yaml
}

# Base helm command
$helmBase = "helm upgrade --install"
$valuesFile = "environments/$Environment/values.yaml"

# Services to deploy
$services = if ($Service -eq "all") {
    @("auth-service", "booking-service", "location-service", "notification-service", "otp-service", "frontend")
} else {
    @($Service)
}

foreach ($svc in $services) {
    $chartPath = "charts/$svc"
    if (Test-Path $chartPath) {
        Write-Host "`nDeploying $svc..." -ForegroundColor Green
        $cmd = "$helmBase $svc $chartPath --namespace $Namespace -f $valuesFile -f global-values.yaml"
        Invoke-Expression $cmd
    } else {
        Write-Warning "Chart not found: $chartPath"
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nGet status:" -ForegroundColor Cyan
Write-Host "kubectl get pods -n $Namespace" -ForegroundColor White
Write-Host "kubectl get svc -n $Namespace" -ForegroundColor White
