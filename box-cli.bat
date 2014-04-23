@echo off
set ANT_HOME=%CD%\build\cfdistro\ant\
if "%1" == "" goto MENU
set var1=%1
SHIFT
:Loop
IF "%1"=="" GOTO Continue
SET var1=%var1% -D%1%
SHIFT
SET var1=%var1%=%1%
SHIFT
GOTO Loop
:Continue
call build\cfdistro\ant\bin\ant.bat -nouserlib -f build/build.xml %var1%
goto end
:MENU
cls
echo.
echo       box-cli menu
REM echo       usage: box-cli.bat [start|stop|{target}]
echo.
echo       1. Start server and open browser
echo       2. Stop server
echo       3. List available targets
echo       4. Update project
echo       5. Run Target
echo       6. Quit
echo.
set choice=
set /p choice=      Enter option 1, 2, 3, 4, 5 or 6 :
echo.
if not '%choice%'=='' set choice=%choice:~0,1%
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
call build\cfdistro\ant\bin\ant.bat -f build/build.xml build.start.launch
echo to stop the server, run this again or run: box-cli.bat stop
goto end
::
:stopServer
call build\cfdistro\ant\bin\ant.bat -f build/build.xml server.stop
goto end
::
:listTargets
call build\cfdistro\ant\bin\ant.bat -f build/build.xml help
echo       press any key ...
pause > nul
goto MENU
::
:updateProject
call build\cfdistro\ant\bin\ant.bat -f build/build.xml project.update
echo       press any key ...
pause > nul
goto MENU
::
:runTarget
set target=
set /p target=      Enter target name:
if not '%target%'=='' call build\cfdistro\ant\bin\ant.bat -f build/build.xml %target%
echo       press any key ...
pause > nul
goto MENU
::
:end
set choice=
echo       press any key ...
pause
REM EXIT
	
			
