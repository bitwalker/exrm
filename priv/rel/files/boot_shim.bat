@if defined ELIXIR_CLI_ECHO (@echo on) else (@echo off)

:: Determine if the current user has admin permissions or not.
@echo Administrative permissions required. Detecting permissions...

@net session >nul 2>&1
if %errorLevel% == 0 (set is_admin="true") else (set is_admin="false")

:: Set variables that describe the release
@set rel_name={{{PROJECT_NAME}}}
@set erl_opts={{{ERL_OPTS}}}

:: Discover the release root directory from the directory of this script
@set script_dir=%~dp0
@for %%A in ("%script_dir%\..") do @(
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

if %is_admin% == "true" (
call "%rel_dir%\%rel_name%.bat" %*
) else (
  @echo You do not have administrator permissions. Please login as an administrator to proceed.
)
  
