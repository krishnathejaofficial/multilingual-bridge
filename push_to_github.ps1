#!/usr/bin/env pwsh
<#
.SYNOPSIS
    One-shot script: initializes git, commits all files, and pushes to GitHub.
    Run this from: k:\software services\multilingual_bridge\

.USAGE
    cd "k:\software services\multilingual_bridge"
    .\push_to_github.ps1
#>

param(
    [string]$GitHubUsername = "krishnathejaofficial",
    [string]$RepoName = "multilingual-bridge"
)

$RepoRoot = $PSScriptRoot
$RemoteUrl = "https://github.com/$GitHubUsername/$RepoName.git"

Write-Host "`n== Multilingual Bridge — GitHub Push Script ==" -ForegroundColor Cyan
Write-Host "Repo root : $RepoRoot"
Write-Host "Remote    : $RemoteUrl`n"

Set-Location $RepoRoot

# 1. Init git (safe to run even if already init'd)
git init --initial-branch=main
if ($LASTEXITCODE -ne 0) { git init; git checkout -b main 2>$null }

# 2. Stage everything
git add .

# 3. Show what will be committed
Write-Host "`n--- Files staged ---" -ForegroundColor Yellow
git status --short

# 4. Commit
$CommitMsg = "feat: Multilingual Bridge v1.0.0 — FastAPI backend + Flutter app"
git commit -m $CommitMsg

# 5. Set remote (remove existing if any, then re-add)
git remote remove origin 2>$null
git remote add origin $RemoteUrl

# 6. Push
Write-Host "`n--- Pushing to $RemoteUrl ---" -ForegroundColor Green
git push -u origin main --force

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nSUCCESS! Code pushed to: https://github.com/$GitHubUsername/$RepoName" -ForegroundColor Green
    Write-Host "Next: Go to vercel.com -> New Project -> Import from GitHub`n"
} else {
    Write-Host "`nPush failed. If asked for credentials:" -ForegroundColor Red
    Write-Host "  Username: $GitHubUsername"
    Write-Host "  Password: use a GitHub Personal Access Token (not your password)"
    Write-Host "  Get token: https://github.com/settings/tokens/new (check 'repo' scope)`n"
}
