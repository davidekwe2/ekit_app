# PowerShell script to remove firebase_options.dart from git history
# WARNING: This will rewrite git history. Make sure you have a backup!

Write-Host "Removing firebase_options.dart from git history..." -ForegroundColor Yellow
Write-Host "This will rewrite your git history. Make sure you have a backup!" -ForegroundColor Red
Write-Host ""

# Check if git-filter-repo is available
$hasFilterRepo = Get-Command git-filter-repo -ErrorAction SilentlyContinue

if ($hasFilterRepo) {
    Write-Host "Using git-filter-repo..." -ForegroundColor Green
    git filter-repo --path lib/firebase_options.dart --invert-paths --force
    Write-Host "Done! Now force push with: git push origin --force --all" -ForegroundColor Green
} else {
    Write-Host "git-filter-repo not found. Using git filter-branch..." -ForegroundColor Yellow
    Write-Host "This is slower but will work." -ForegroundColor Yellow
    Write-Host ""
    
    # Remove from all branches
    git filter-branch --force --index-filter "git rm --cached --ignore-unmatch lib/firebase_options.dart" --prune-empty --tag-name-filter cat -- --all
    
    # Clean up
    git reflog expire --expire=now --all
    git gc --prune=now --aggressive
    
    Write-Host ""
    Write-Host "Done! Now force push with: git push origin --force --all" -ForegroundColor Green
    Write-Host "WARNING: This will rewrite history on remote. Coordinate with your team!" -ForegroundColor Red
}

Write-Host ""
Write-Host "After removing from history:" -ForegroundColor Cyan
Write-Host "1. Rotate ALL API keys in Firebase Console" -ForegroundColor Yellow
Write-Host "2. Run: flutterfire configure --project=ekitnote" -ForegroundColor Yellow
Write-Host "3. Verify .gitignore includes firebase_options.dart" -ForegroundColor Yellow

