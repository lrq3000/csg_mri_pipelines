pyinstaller --onedir pathmatcher_pyinstaller-win64.spec > pyinstaller-log.txt 2>&1 & type pyinstaller-log.txt
pyi-archive_viewer dist\pathmatcher.exe -r -b > pyinstaller-dependencies.txt
pause
