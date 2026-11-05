@echo off
REM ============================================================
REM  Moeen - build and publish to GitHub Pages
REM  Usage:  publish_github_pages.bat            (repo named "moeen")
REM          publish_github_pages.bat my-repo    (other repo name)
REM ============================================================
setlocal
set REPO=%~1
if "%REPO%"=="" set REPO=moeen

echo.
echo [1/3] Building Moeen for the web (base path /%REPO%/) ...
call flutter build web --release --base-href /%REPO%/
if errorlevel 1 (
  echo BUILD FAILED. Fix the errors above and run again.
  exit /b 1
)

echo [2/3] Copying the build to the docs folder ...
if exist docs rmdir /s /q docs
xcopy build\web docs\ /e /i /q >nul
type nul > docs\.nojekyll

if not exist .git (
  echo.
  echo Done. The site is in the "docs" folder.
  echo This folder is not a git repository yet - see PUBLISH_IPHONE_AR.md, step 2.
  exit /b 0
)

echo [3/3] Uploading to GitHub ...
git add -A
git commit -m "Publish Moeen" >nul
git push -u origin main
if errorlevel 1 (
  echo PUSH FAILED. Check your internet connection or GitHub sign-in, then run again.
  exit /b 1
)
echo.
echo Published. In 1-2 minutes open:  https://YOUR-USERNAME.github.io/%REPO%/
endlocal
