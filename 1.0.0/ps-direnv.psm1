if (Test-Path Function:\PromptBackup) {
    Write-Host "duplicate backup Prompt function" -ForegroundColor Cyan
}

if (Test-Path Function:\Prompt) {
    Rename-Item Function:\Prompt global:PromptBackup
}

function global:Prompt {
    try {
        if (Test-Path ./.env) {
            Set-DotEnv | Out-Null
        } elseif (Test-Path ENV:DOTENV_ADDED_VARS) {
            Remove-DotEnv
        }

        # Fall back on existing Prompt function
        if (Test-Path Function:\PromptBackup) {
            PromptBackup
        } 
    }
    catch {
        Write-Host $($_.Exception.Message) -ForegroundColor Red
    }
}

Function Set-DotEnv {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.Object[]])]
    param(
        [switch]$recurse, #NYI
        [string]$path = './.env',
        [switch]$returnvars
    )
    Write-Host "Setting env vars"
    $dotenv_added_vars = @() # a special var that tells us what we added
    $linecursor = 0

    $content = Get-Content $path -ErrorAction SilentlyContinue # if i doesn't exist, forget it

    $content | ForEach-Object { # go through line by line
        [string]$line = $_.trim() # trim whitespace
        if ($line -like "#*") {
            # it's a comment
            Write-Verbose "Found comment $line at line $linecursor. discarding"
        }
        elseif ($line -eq "") {
            # it's a blank line
            Write-Verbose "Found a blank line at line $linecursor, discarding"
        }
        else {
            # it's not a comment, parse it
            # find the first '='
            $eq = $line.IndexOf('=')
            $fq = $eq + 1
            $ln = $line.Length
            Write-Verbose "Found an assignment operator at position $eq in a string of length $ln on line $linecursor"

            $key = $line.Substring(0, $eq).trim()
            $value = $line.substring($fq, $line.Length - $fq).trim()
            Write-Verbose "Found $key with value $value"

            if ($value -match "`'|`"") {
                Write-Verbose "`tQuoted value found, trimming quotes"
                $value = $value.trim('"').trim("'")
                Write-Verbose "`tValue is now $value"
            }

            [System.Environment]::SetEnvironmentVariable($key, $value)

            $added_vars += @{$key = $value }
            $ENV:DOTENV_ADDED_VARS = ($added_vars.keys -join (","))
        }
        $linecursor++
    }

    if ($returnvars) {
        Write-Verbose "returnvars was specified, returning the array of found vars"
        return $dotenv_added_vars
    }

}

Function Remove-DotEnv {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $added_vars = $ENV:DOTENV_ADDED_VARS
    if ($null -ne $added_vars) {
        Write-Host "Removing env vars"
        $added_vars.split(",") | ForEach-Object {
            Remove-Item ENV:$_ -ErrorAction SilentlyContinue
        }
    }

    Remove-item ENV:DOTENV_ADDED_VARS -ErrorAction SilentlyContinue

}