@echo off
set CFDISTRO_HOME=%userprofile%\cfdistro
set FILE_URL="http://cfmlprojects.org/artifacts/cfdistro/latest/cfdistro.zip"
set FILE_DEST=%CFDISTRO_HOME%\cfdistro.zip
set buildfile=build/build.xml
set ANT_HOME=%CFDISTRO_HOME%\ant
set ANT_CMD=%CFDISTRO_HOME%\ant\bin\ant.bat
if not exist "%CFDISTRO_HOME%" (
  mkdir "%CFDISTRO_HOME%"
)
REM if build file does not exist
if not exist "%CFDISTRO_HOME%\build.xml" (
  REM Try to download cfdistro file
  if not exist "%FILE_DEST%" (
    echo Downloading with powershell: %FILE_URL% to %FILE_DEST%
    powershell.exe -command "$webclient = New-Object System.Net.WebClient; $url = \"%FILE_URL%\"; $file = \"%FILE_DEST%\"; $webclient.DownloadFile($url,$file);"
	REM if error encountered, try another method to download
	REM using file existance check as errorlevel does not get reset properly
    if not exist "%FILE_DEST%" (
      echo Powershell download failed. Trying with ActiveXObject
  	  cscript /nologo build/resource/wget.js %FILE_URL% %FILE_DEST%
      if not exist "%FILE_DEST%" (
          echo 2nd Download attempt failed.
          echo Try to manually download from %FILE_URL%
          echo and expand in %FILE_DEST%
          EXIT /B
      ) else (
        echo Download successful
      )
	)
  )
)
REM if build file does not exist
if not exist "%CFDISTRO_HOME%\build.xml" (
  if exist "%FILE_DEST%" (
    echo Expanding with powershell to: %CFDISTRO_HOME%
    powershell -command "$shell_app=new-object -com shell.application; $zip_file = $shell_app.namespace(\"%FILE_DEST%\"); $destination = $shell_app.namespace(\"%CFDISTRO_HOME%\"); $destination.Copyhere($zip_file.items())"
    REM remove zip file
	del %FILE_DEST%
  )
)
REM must have build file for remainder of file, so check it exists
if not exist "%CFDISTRO_HOME%\build.xml" (
  echo Build file does not exist at %CFDISTRO_HOME%\build.xml
  echo Exiting.
  EXIT /B
)
if "%1" == "" goto MENU
set args=%1
SHIFT
:Loop
IF "%1" == "" GOTO Continue
SET args=%args% -D%1%
SHIFT
IF "%1" == "" GOTO Continue
SET args=%args%=%1%
SHIFT
GOTO Loop
:Continue
if not exist %buildfile% (
	set buildfile="%CFDISTRO_HOME%\build.xml"
)
call "%ANT_CMD%" -nouserlib -f %buildfile% %args%
goto end
:MENU
cls
echo.
echo       box-cli menu
REM echo       usage: box-cli.bat [start|stop|{target}]
echo.
echo       0. Build
echo       1. Start server and open browser
echo       2. Stop server
echo       3. List available targets
echo       4. Update project
echo       5. Run Target
echo       6. Quit
echo.
set choice=
set /p choice=      Enter option 0, 1, 2, 3, 4, 5 or 6 :
echo.
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='0' goto build
if '%choice%'=='1' goto startServer
if '%choice%'=='2' goto stopServer
if '%choice%'=='3' goto listTargets
if '%choice%'=='4' goto updateProject
if '%choice%'=='5' goto runTarget
if '%choice%'=='6' goto end
::
echo.
echo.
echo "%choice%" is not a valid option - try again
echo.
pause
goto MENU
::
:startServer
cls
call "%ANT_CMD%" -nouserlib -f %buildfile% build.start.launch
echo to stop the server, run this again or run: box-cli.bat stop
goto end
::
:stopServer
call "%ANT_CMD%" -nouserlib -f %buildfile% server.stop
goto end
::
:listTargets
call "%ANT_CMD%" -nouserlib -f %buildfile% help
echo       press any key ...
pause > nul
goto MENU
::
:build
call "%ANT_CMD%" -nouserlib -f %buildfile% build
echo       press any key ...
pause > nul
goto MENU
::
:updateProject
call "%ANT_CMD%" -nouserlib -f %buildfile% project.update
echo       press any key ...
pause > nul
goto MENU
::
:runTarget
set target=
set /p target=      Enter target name:
if not "%target%"=="" call %0 %target%
echo       press any key ...
pause > nul
goto MENU
::
:end
set choice=
echo       press any key ...
pause
REM EXIT
			
