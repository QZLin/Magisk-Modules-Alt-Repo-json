#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Reconstruct an SSH key pair from the KEY_BOT environment variable on Linux.
.DESCRIPTION
    This script extracts an SSH private key from the KEY_BOT environment variable,
    validates it, and reconstructs the full key pair in the user's .ssh directory.
    It will overwrite any existing id_rsa key pair.
#>

# Set strict mode for better error handling and script reliability.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Main script execution block with error handling ---
try {
    # Check for the presence of ssh-keygen.
    if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
        throw "OpenSSH client is not installed or not in the PATH. On Ubuntu, install it with: sudo apt install openssh-client"
    }

    # Define necessary paths.
    $sshDir = Join-Path $HOME ".ssh"
    $privateKeyPath = Join-Path $sshDir "id_ed25519"
    $publicKeyPath = "$privateKeyPath.pub"

    # Create .ssh directory if it doesn't exist.
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force > $null
        Write-Host "Created SSH directory: $sshDir"
    }

    # Retrieve the private key from the environment variable.
    $keyContent = "$env:KEY_BOT"
    if ([string]::IsNullOrWhiteSpace($keyContent)) {
        throw "Environment variable KEY_BOT is not set or is empty."
    }

    # --- Process and validate the private key ---
    Write-Host "Processing SSH key from environment variable..."
    
    # Clean up and format the key content.
    $processedKey = ($keyContent.Trim() -replace "\\n", "`n") + "`n"
    
    # Basic validation of the key structure.
    if ($processedKey -notmatch '-----BEGIN [A-Z\s]+ PRIVATE KEY-----') {
        throw "The key content does not appear to be a valid SSH private key."
    }
    
    # --- Advanced validation using a temporary file ---
    $tempFile = New-TemporaryFile
    try {
        # Write to temp file for validation by ssh-keygen.
        $processedKey | Out-File -FilePath $tempFile.FullName -Encoding utf8 -NoNewline

        # Use ssh-keygen to validate the key format.
        & ssh-keygen -l -f $tempFile.FullName 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "The private key format is invalid as reported by ssh-keygen."
        }

        # --- Write keys and set permissions ---
        Write-Host "Private key validated successfully. Overwriting existing key..."
        
        # Write the private key to its final destination.
        $processedKey | Out-File -FilePath $privateKeyPath -Encoding utf8 -NoNewline

        # Set strict file permissions for the private key.
        chmod 600 $privateKeyPath

        # Generate and save the corresponding public key.
        Write-Host "Generating public key..."
        $publicKeyContent = & ssh-keygen -y -f $privateKeyPath
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to generate public key from the private key."
        }
        
        # Write the public key to its file.
        $publicKeyContent | Out-File -FilePath $publicKeyPath -Encoding utf8

        # Set appropriate permissions for the public key.
        chmod 644 $publicKeyPath

        # --- Display success information ---
        Write-Host "SSH key pair successfully reconstructed!" -ForegroundColor Green
        Write-Host "Private key: $privateKeyPath" -ForegroundColor Cyan
        Write-Host "Public key: $publicKeyPath" -ForegroundColor Cyan
        
        Write-Host "`nKey fingerprint:"
        & ssh-keygen -l -f $privateKeyPath
        
        Write-Host "`nPublic key content:"
        Get-Content $publicKeyPath

    }
    finally {
        # Ensure the temporary file is always removed.
        if ($tempFile) {
            Remove-Item $tempFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}
catch {
    # Catch any terminating errors from the script.
    Write-Error "An error occurred: $_"
    exit 1
}