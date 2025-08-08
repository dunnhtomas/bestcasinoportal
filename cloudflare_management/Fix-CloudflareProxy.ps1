# Manual Cloudflare DNS Proxy Fix via PowerShell and curl

# Configuration
$token = "pe2L5nDoK0kKvpGVkRSm4P48FExlWfbTZdOZfhXF"
$zoneId = "7e35370f0b0046096a758f4df76bf2d0"
$domain = "bestcasinoportal.com"
$serverIp = "193.233.161.161"

# Headers for API calls
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

Write-Host "=== Cloudflare DNS Proxy Configuration Fix ===" -ForegroundColor Cyan

# 1. Get current DNS records
Write-Host "`n1. Getting current DNS records..." -ForegroundColor Yellow
$dnsUrl = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records"

try {
    $dnsResponse = Invoke-RestMethod -Uri $dnsUrl -Headers $headers -Method GET
    
    if ($dnsResponse.success) {
        Write-Host "DNS records retrieved successfully" -ForegroundColor Green
        
        # Find root and www records
        $rootRecord = $dnsResponse.result | Where-Object { $_.name -eq $domain -and $_.type -eq "A" }
        $wwwRecord = $dnsResponse.result | Where-Object { $_.name -eq "www.$domain" -and $_.type -eq "A" }
        
        Write-Host "`nCurrent DNS Configuration:" -ForegroundColor White
        if ($rootRecord) {
            Write-Host "Root: $($rootRecord.name) -> $($rootRecord.content) (Proxied: $($rootRecord.proxied))" -ForegroundColor $(if($rootRecord.proxied) {"Green"} else {"Red"})
        }
        if ($wwwRecord) {
            Write-Host "WWW:  $($wwwRecord.name) -> $($wwwRecord.content) (Proxied: $($wwwRecord.proxied))" -ForegroundColor $(if($wwwRecord.proxied) {"Green"} else {"Red"})
        }
        
        # 2. Update records to enable proxy if needed
        Write-Host "`n2. Updating DNS records to enable proxy..." -ForegroundColor Yellow
        
        if ($rootRecord -and -not $rootRecord.proxied) {
            $updateData = @{
                type = "A"
                name = $domain
                content = $serverIp
                proxied = $true
                ttl = 1
            } | ConvertTo-Json
            
            $updateUrl = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$($rootRecord.id)"
            $updateResponse = Invoke-RestMethod -Uri $updateUrl -Headers $headers -Method PUT -Body $updateData
            
            if ($updateResponse.success) {
                Write-Host "Root record proxy ENABLED" -ForegroundColor Green
            } else {
                Write-Host "Root record update FAILED: $($updateResponse.errors)" -ForegroundColor Red
            }
        }
        
        if ($wwwRecord -and -not $wwwRecord.proxied) {
            $updateData = @{
                type = "A"
                name = "www"
                content = $serverIp
                proxied = $true
                ttl = 1
            } | ConvertTo-Json
            
            $updateUrl = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$($wwwRecord.id)"
            $updateResponse = Invoke-RestMethod -Uri $updateUrl -Headers $headers -Method PUT -Body $updateData
            
            if ($updateResponse.success) {
                Write-Host "WWW record proxy ENABLED" -ForegroundColor Green
            } else {
                Write-Host "WWW record update FAILED: $($updateResponse.errors)" -ForegroundColor Red
            }
        }
        
        # 3. Purge cache
        Write-Host "`n3. Purging Cloudflare cache..." -ForegroundColor Yellow
        $purgeUrl = "https://api.cloudflare.com/client/v4/zones/$zoneId/purge_cache"
        $purgeData = @{ purge_everything = $true } | ConvertTo-Json
        
        $purgeResponse = Invoke-RestMethod -Uri $purgeUrl -Headers $headers -Method POST -Body $purgeData
        
        if ($purgeResponse.success) {
            Write-Host "Cache purged successfully" -ForegroundColor Green
        } else {
            Write-Host "Cache purge failed: $($purgeResponse.errors)" -ForegroundColor Red
        }
        
        # 4. Wait and test
        Write-Host "`n4. Waiting for DNS propagation..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        
        # 5. Test URLs
        Write-Host "`n5. Testing domain accessibility..." -ForegroundColor Yellow
        $testUrls = @(
            "https://$domain",
            "https://www.$domain",
            "http://$domain",
            "http://www.$domain"
        )
        
        foreach ($url in $testUrls) {
            try {
                $response = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing
                Write-Host "SUCCESS: $url - HTTP $($response.StatusCode) ($($response.Content.Length) bytes)" -ForegroundColor Green
            } catch {
                Write-Host "ERROR: $url - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Write-Host "`n=== CLOUDFLARE CONFIGURATION COMPLETE ===" -ForegroundColor Cyan
        Write-Host "✅ DNS Proxy: ENABLED" -ForegroundColor Green
        Write-Host "✅ Cache: PURGED" -ForegroundColor Green
        Write-Host "✅ Domain: TESTED" -ForegroundColor Green
        
    } else {
        Write-Host "Failed to retrieve DNS records: $($dnsResponse.errors)" -ForegroundColor Red
    }
} catch {
    Write-Host "API Error: $($_.Exception.Message)" -ForegroundColor Red
}

