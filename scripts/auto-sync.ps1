param(
    [string]$Branch = "main",
    [string]$Remote = "origin",
    [switch]$Push,
    [switch]$UseStash
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot
Set-Location -Path ".."

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "[auto-sync] Starting at $timestamp"

# Ensure we're inside a git repository
$insideRepo = git rev-parse --is-inside-work-tree 2>$null
if ($insideRepo -ne "true") {
    throw "Not inside a git repository."
}

$currentBranch = (git branch --show-current).Trim()
if ([string]::IsNullOrWhiteSpace($currentBranch)) {
    throw "Could not determine current branch."
}

if ($currentBranch -ne $Branch) {
    Write-Host "[auto-sync] Switching branch $currentBranch -> $Branch"
    git checkout $Branch
}

# By default, unattended runs skip sync when there are local changes.
$stashCreated = $false
$hasTrackedChanges = $false
$hasUntrackedChanges = $false

git diff --quiet
if ($LASTEXITCODE -ne 0) {
    $hasTrackedChanges = $true
}

$untracked = git ls-files --others --exclude-standard
if (-not [string]::IsNullOrWhiteSpace($untracked)) {
    $hasUntrackedChanges = $true
}

if ($hasTrackedChanges -or $hasUntrackedChanges) {
    if (-not $UseStash) {
        Write-Host "[auto-sync] Local changes detected; skipped sync to avoid interactive file-lock prompts."
        Write-Host "[auto-sync] Re-run with -UseStash for manual conflict-handling mode."
        exit 0
    } else {
        $stashMsg = "auto-sync temp stash $timestamp"
        git stash push -u -m $stashMsg
        if ($LASTEXITCODE -eq 0) {
            $stashCreated = $true
            Write-Host "[auto-sync] Saved local changes to stash"
        } else {
            throw "Failed to stash local changes."
        }
    }
} else {
    Write-Host "[auto-sync] No local changes to stash"
}

Write-Host "[auto-sync] Pulling latest from $Remote/$Branch with rebase"
git pull --rebase $Remote $Branch

if ($stashCreated) {
    Write-Host "[auto-sync] Restoring stashed local changes"
    git stash pop
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[auto-sync] Stash pop had conflicts. Your stash entry is still saved for manual recovery."
        exit 1
    }
}

if ($Push) {
    Write-Host "[auto-sync] Pushing to $Remote/$Branch"
    git push $Remote $Branch
} else {
    Write-Host "[auto-sync] Skipped push (use -Push to enable)"
}

Write-Host "[auto-sync] Done"
