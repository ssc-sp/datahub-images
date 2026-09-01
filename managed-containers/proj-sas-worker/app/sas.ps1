$projCode = $env:PROJ_CD
$resource_group_name = $env:PROJ_RG
$key_vault_name = $env:PROJ_KV
$projSub = $env:PROJ_SUB
$storage_acct_name = $env:PROJ_STORAGE_ACCT
$azClientId = $env:CLIENT_ID
$context = $null;
$currentDate = Get-Date
$fiscalYearStart = if ($currentDate.Month -ge 4 ) { [datetime]::new($currentDate.Year, 4, 1) } else { [datetime]::new($currentDate.Year - 1, 4, 1) }
$sas_secret_name = "container-sas"
$container_name = "datahub"

if ($env:ROOT_CA) {
    try {
        Write-Host "Installing custom root CA"
        $dest = "/tmp/custom-root-ca.crt"
        Copy-Item -Path "/etc/ssl/certs/ca-certificates.crt" -Destination $dest -Force
        Add-Content -Path $dest -Value "`n$($env:ROOT_CA)`n"
        Write-Host "Custom RootCA set to $dest"
    }
    catch {
        Write-Host "Failed to install custom root CA: $($_.Exception.Message)"
    }
}

try {
    Set-AzContext -Subscription $projSub -ErrorAction Stop | Out-Null
} catch {
    try {
        if ($azClientId) {
            Connect-AzAccount -Identity -AccountId $azClientId -ErrorAction Stop | Out-Null
        } else {
            Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
        }
    } catch {
        Write-Error ("Managed identity login failed: {0}" -f $_.Exception.Message)
        exit 1
    }
    try {
        Set-AzContext -Subscription $projSub -ErrorAction Stop | Out-Null
    } catch {
        Write-Error ("Authenticated, but cannot access or set subscription '{0}': {1}" -f $projSub, $_.Exception.Message)
        exit 1
    }
}

Write-Host "Using Azure subscription: $((Get-AzContext).Subscription.Name) ($((Get-AzContext).Subscription.Id))"
Write-Host Rotate the SAS token in AKV Secret name storage-sas for project $projCode

try {
    $acct = Get-AzStorageAccount -ResourceGroupName $resource_group_name -AccountName $storage_acct_name `
            -ErrorAction Stop -WarningAction SilentlyContinue
    if (-not $acct -or -not $acct.Context) {
        Write-Error ("Storage account '{0}' found but no usable Context returned. Check Az.Storage version/permissions." -f $storage_acct_name)
        exit 1
    }
    $context = $acct.Context
}
catch {
    $reason = $_.Exception.Message
    if ($_.Exception.InnerException) { $reason += " | " + $_.Exception.InnerException.Message }
    Write-Error ("Failed to get storage account '{0}' in resource group '{1}'. {2}" -f $storage_acct_name, $resource_group_name, $reason)
    exit 1
}

try {
  $secret_start = (Get-AzKeyVaultSecret -VaultName $key_vault_name -Name $sas_secret_name).tags.start
  $secret_expiry = (Get-AzKeyVaultSecret -VaultName $key_vault_name -Name $sas_secret_name).tags.expiry
  Write-Output "Existing expiry date: from $secret_start to $secret_expiry for key vault $key_vault_name secret $sas_secret_name"

  if ((get-date).addDays(14) -ge (get-date $secret_expiry)) {
    Write-Output "Rotating SAS token - generating a new SAS token"
    $new_start = (get-date).addDays(-1).toString("yyyy-MM-dd")
    $new_expiry = (get-date).addDays(91).toString("yyyy-MM-dd")
    $new_tags = @{ "start" = "$new_start"; "expiry" = "$new_expiry" } 

    $new_sas = New-AzStorageContainerSASToken -Name $container_name -Permission rwd -StartTime $new_start -ExpiryTime $new_expiry -context $context
    $new_sas_secret = ConvertTo-SecureString -String "$new_sas" -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $key_vault_name -Name $sas_secret_name -SecretValue $new_sas_secret -Tags $new_tags

    Write-Output "New expiry date: from $new_start to $new_expiry"
  }

  Write-Output "Completed: New expiry $new_expiry"
}
catch {
    Write-Host "Error rotating SAS for project $($projCode.ToUpper()) !!!"
    Write-Host "Exception: $($_.Exception)"
    Write-Host "Error Message: $($_.Exception.Message)"
    exit 1
}

