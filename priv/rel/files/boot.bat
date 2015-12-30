:: This batch file handles managing an Erlang node as a Windows service.
::
:: Commands provided:
::
:: * install - install the release as a Windows service
:: * start - start the service and Erlang node
:: * stop - stop the service and Erlang node
:: * restart - run the stop command and start command
:: * uninstall - uninstall the service and kill a running node
:: * ping - check if the node is running
:: * console - start the Erlang release in a `werl` Windows shell
:: * attach - connect to a running node and open an interactive console
:: * list - display a listing of installed Erlang services
:: * usage - display available commands

@if defined ELIXIR_CLI_ECHO (@echo on) else (@echo off)

:: Set variables that describe the release
@set rel_name={{{PROJECT_NAME}}}
@set erl_opts={{{ERL_OPTS}}}
@set conform_opts=""

:: Discover the release root directory from the directory of this script
@set script_dir=%~dp0
@for %%A in ("%script_dir%\..\..") do @(
  set release_root_dir=%%~fA
)
@set start_erl=%release_root_dir%\releases\start_erl.data
@for /f "delims=" %%i in ('type %start_erl%') do @(
  set start_erl_data=%%i
)
@for /f "tokens=1,* delims=\ " %%a in ("%start_erl_data%") do @(
  set erts_vsn=%%a
  set rel_vsn=%%b
)
@set rel_dir=%release_root_dir%\releases\%rel_vsn%

@call :find_erts_dir
@call :find_sys_config
@call :set_boot_script_var

@set service_name=%rel_name%_%rel_vsn%
@set bindir=%erts_dir%\bin
@set vm_args=%rel_dir%\vm.args
@set progname=erl.exe
@set clean_boot_script=%release_root_dir%\bin\start_clean
@set erlsrv=%bindir%\erlsrv.exe
@set epmd=%bindir%\epmd.exe
@set escript=%bindir%\escript.exe
@set werl=%bindir%\werl.exe
@set nodetool=%release_root_dir%\bin\nodetool
@set conform=%rel_dir%\conform

:: Extract node type and name from vm.args
@for /f "usebackq tokens=1-2" %%I in (`findstr /b "\-name \-sname" "%vm_args%"`) do @(
  set node_type=%%I
  set node_name=%%J
)

:: Extract cookie from vm.args
@for /f "usebackq tokens=1-2" %%I in (`findstr /b \-setcookie "%vm_args%"`) do @(
  set cookie=%%J
)

:: Write the erl.ini file to set up paths relative to this script
@call :write_ini

:: If a start.boot file is not present, copy one from the named .boot file
@if not exist "%rel_dir%\start.boot" (
  copy "%rel_dir%\%rel_name%.boot" "%rel_dir%\start.boot" >nul
)

@if "%1"=="install" @goto install
@if "%1"=="uninstall" @goto uninstall
@if "%1"=="start" @goto start
@if "%1"=="stop" @goto stop
@if "%1"=="restart" @call :stop && @goto start
@if "%1"=="upgrade" @goto relup
@if "%1"=="downgrade" @goto relup
@if "%1"=="console" @goto console
@if "%1"=="ping" @goto ping
@if "%1"=="list" @goto list
@if "%1"=="attach" @goto attach
@if "%1"=="" @goto usage
@echo Unknown command: "%1"

@goto :eof

:: Find the ERTS dir
:find_erts_dir
@set possible_erts_dir=%release_root_dir%\erts-%erts_vsn%
@if exist "%possible_erts_dir%" (
  call :set_erts_dir_from_default
) else (
  call :set_erts_dir_from_erl
)
@goto :eof

:: Set the ERTS dir from the passed in erts_vsn
:set_erts_dir_from_default
@set erts_dir=%possible_erts_dir%
@for %%e in ("%erts_dir%") do set erts_dir=%%~se
@set rootdir=%release_root_dir%
@for %%r in ("%rootdir%") do set rootdir=%%~sr
@goto :eof

:: Set the ERTS dir from erl
:set_erts_dir_from_erl
@for /f "delims=" %%i in ('where erl') do @(
  set erl=%%~si
)
@set dir_cmd="%erl%" -noshell -eval "io:format(\"~s\", [filename:nativename(code:root_dir())])." -s init stop
%dir_cmd% > %TEMP%/erlroot.txt 
@set /P erl_root=< %TEMP%/erlroot.txt
@for %%f in ("%erl_root%") do set erl_root=%%~sf
@set erts_dir=%erl_root%\erts-%erts_vsn%
@for %%e in ("%erts_dir%") do set erts_dir=%%~se
@set rootdir=%erl_root%
@goto :eof

:: Find the sys.config file
:find_sys_config
@set possible_sys=%rel_dir%\sys.config
@if exist %possible_sys% (
  set sys_config=%possible_sys%
)
@goto :eof

:generate_config
@set conform_schema="%rel_dir%\%rel_name%.schema.exs"
@if "%RELEASE_CONFIG_FILE%"=="" (
  set conform_conf="%rel_dir%\%rel_name%.conf"
) else (
  if exist "%RELEASE_CONFIG_FILE%" (
    set conform_conf="%RELEASE_CONFIG_FILE%"
  ) else (
    echo "RELEASE_CONFIG_FILE not found"
    set ERRORLEVEL=1
    exit /b %ERRORLEVEL%
    goto :eof
  )
)
@if exist "%conform_schema%" (
  if exist "%conform_conf%" (
    set conform_opts="-conform_schema %conform_schema% -conform_config %conform_conf%"
    "%escript%" "%conform%" --conf "%conform_conf%" --schema "%conform_schema%" --config "%sys_config%" --output-dir "%rel_dir%"
    if 1==%ERRORLEVEL% (
      exit /b %ERRORLEVEL%
    )
  ) else (
    goto :eof
  )
)
@goto :eof

:: set boot_script variable
:set_boot_script_var
@if exist "%rel_dir%\%rel_name%.boot" (
  set boot_script=%rel_dir%\%rel_name%
) else (
  set boot_script=%rel_dir%\start
)
@goto :eof

:: Write the erl.ini file
:write_ini
@set erl_ini=%erts_dir%\bin\erl.ini
@set converted_bindir=%bindir:\=\\%
@set converted_rootdir=%rootdir:\=\\%
@echo [erlang] > "%erl_ini%"
@echo Bindir=%converted_bindir% >> "%erl_ini%"
@echo Progname=%progname% >> "%erl_ini%"
@echo Rootdir=%converted_rootdir% >> "%erl_ini%"
@goto :eof

:: Display usage information
:usage
@echo usage: %~n0 ^(install^|uninstall^|start^|stop^|restart^|upgrade^|downgrade^|console^|ping^|list^|attach^)
@goto :eof

:: Install the release as a Windows service
:: or install the specified version passed as argument
:install
@if "" == "%2" (
  :: Install the service
  set args=%erl_opts% %conform_opts% -setcookie %cookie% ++ -rootdir \"%rootdir%\"
  set svc_machine=%erts_dir%\bin\start_erl.exe
  set description=Erlang node %node_name% in %rootdir%
  %erlsrv% add %service_name% %node_type% "%node_name%" -c "%description%" ^
            -w "%rootdir%" -m "%svc_machine%" -args "%args%" ^
            -stopaction "init:stop()."
) else (
  :: relup and reldown
  goto relup
)
@goto :eof

:: Uninstall the Windows service
:uninstall
@%erlsrv% remove %service_name%
@%epmd% -kill
@goto :eof

:: Start the Windows service
:start
@call :generate_config
@%erlsrv% start %service_name%
@goto :eof

:: Stop the Windows service
:stop
@%erlsrv% stop %service_name%
@goto :eof

:: Relup and reldown
:relup
@if "" == "%2" (
  echo Missing package argument
  echo Usage: %rel_name% %1 {package base name}
  echo NOTE {package base name} MUST NOT include the .tar.gz suffix
  set ERRORLEVEL=1
  exit /b %ERRORLEVEL%
)
@%escript% "%rootdir%/bin/install_upgrade.escript" "%rel_name%" "%node_type%" "%node_name%" "%cookie%" "%2"
@goto :eof

:: Start a console
:console
@call :generate_config
@start "%rel_name% console" %werl% -config "%sys_config%" ^
       -boot "%boot_script%" -boot_var ERTS_LIB_DIR "%erts_dir%"/lib ^
       -env ERL_LIBS "%release_root_dir%"/lib ^
       -pa "%release_root_dir%"/lib "%release_root_dir%"/lib/consolidated ^
       -args_file "%vm_args%" ^
       -user Elixir.IEx.CLI -extra --no-halt +iex

@goto :eof

:: Ping the running node
:ping
@%escript% %nodetool% ping %node_type% "%node_name%" -setcookie "%cookie%"
@goto :eof

:: List installed Erlang services
:list
@%erlsrv% list %service_name%
@goto :eof

:: Attach to a running node
:attach
@%escript% %nodetool% attach %werl% -boot "%clean_boot_script%" -config "%sys_config%" ^
       -pa "%release_root_dir%"/lib "%release_root_dir%"/lib/consolidated ^
       -hidden -noshell ^
       -boot_var ERTS_LIB_DIR "%erts_dir%"/lib ^
       -user Elixir.IEx.CLI "%node_type%" "%node_name%" ^
       -setcookie "%cookie%" -args_file "%vm_args%" ^
       -extra --no-halt +iex -"%node_type%" "%node_name%" --cookie "%cookie%" --remsh "%node_name%"
@goto :eof
