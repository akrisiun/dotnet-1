[CmdletBinding(PositionalBinding=$false)]
param(
    [bool] $CreatePackages,
    [bool] $RunTests = $true,
    [string] $PullRequestNumber
)

Write-Host "Run Parameters:" -ForegroundColor Cyan
Write-Host "  CreatePackages: $CreatePackages"
Write-Host "  RunTests: $RunTests"
Write-Host "  dotnet --version:" (dotnet --version)

$RunTests = $false

$packageOutputFolder = "$PSScriptRoot\.nupkgs"
$projectsToBuild =
    'MiniProfiler.Shared',
    'MiniProfiler',
    'MiniProfiler.EF6',
    'MiniProfiler.EntityFrameworkCore',
    'MiniProfiler.Providers.Sqlite',
    'MiniProfiler.Providers.SqlServer',
    'MiniProfiler.Mvc5',
    'MiniProfiler.AspNetCore',
    'MiniProfiler.AspNetCore.Mvc'

$testsToRun =
    'MiniProfiler.Tests',
    'MiniProfiler.Tests.AspNet'

if ($PullRequestNumber) {
    Write-Host "Building for a pull request (#$PullRequestNumber), skipping packaging." -ForegroundColor Yellow
    $CreatePackages = $false
}

Write-Host "Building solution..." -ForegroundColor "Magenta"
# dotnet build ".\MiniProfiler.sln" /p:CI=true
dotnet build --no-dependencies src\MiniProfiler.Shared\
dotnet build --no-dependencies src\MiniProfiler\
dotnet build --no-dependencies src\MiniProfiler.Mvc5
dotnet build --no-dependencies src\MiniProfiler.EntityFrameworkCore\
dotnet build --no-dependencies src\MiniProfiler.Providers.SqlServer
dotnet build --no-dependencies wwwroot

Write-Host "Done building." -ForegroundColor "Green"

if ($RunTests) {
    foreach ($project in $testsToRun) {
        Write-Host "Running tests: $project (all frameworks)" -ForegroundColor "Magenta"
        Push-Location ".\tests\$project"

        dotnet xunit
        if ($LastExitCode -ne 0) { 
            Write-Host "Error with tests, aborting build." -Foreground "Red"
            Pop-Location
            Exit 1
        }

        Write-Host "Tests passed!" -ForegroundColor "Green"
	    Pop-Location
    }
}

if ($CreatePackages) {
    mkdir -Force $packageOutputFolder | Out-Null
    Write-Host "Clearing existing $packageOutputFolder..." -NoNewline
    Get-ChildItem $packageOutputFolder | Remove-Item
    Write-Host "done." -ForegroundColor "Green"

    Write-Host "Building all packages" -ForegroundColor "Green"

    foreach ($project in $projectsToBuild) {
        Write-Host "Packing $project (dotnet pack)..." -ForegroundColor "Magenta"
        dotnet pack ".\src\$project\$project.csproj" -c Release /p:PackageOutputPath=$packageOutputFolder /p:NoPackageAnalysis=true /p:CI=true
        Write-Host ""
    }
}

Write-Host "Done."