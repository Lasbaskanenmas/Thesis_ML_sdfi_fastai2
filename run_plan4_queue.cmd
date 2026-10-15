@echo off
REM ==============================================================================================
REM  Great Plan 4, Phase 1 queue -- five ConvNeXt+UPerNet arms, 3 folds each, then the pick.
REM  Prepared by the assistant, NOT executed by it. The author launches it, in a standalone cmd
REM  window (not the VSCode terminal), from anywhere:   C:\thesis\ML_sdfi_fastai2\run_plan4_queue.cmd
REM
REM  Per fold: train -> back up the final .pth to HF (non-fatal) -> infer the held-out fold.
REM  A failed train or infer abandons THAT CELL ONLY and the queue moves to the next cell.
REM  Cells 1-4 are scored in their own minimised window while the next cell trains, so the GPU never
REM  waits on CPU scoring; cell 5 is scored in the foreground because the pick needs it.
REM
REM  Preconditions (checked or stated):
REM    * 2026-10-06_plan4_declarations.md reads "status: LOCKED"          (checked below)
REM    * gate_plan4.py printed ALL GATES PASS                             (author's responsibility)
REM  Standing gotcha: after any crash, check nvidia-smi for orphaned workers before relaunching.
REM  This file never kills processes itself, because that would also kill a background scoring job.
REM  Log: C:\thesis\exploratory_data_analysis\logs\plan4_queue.log
REM ==============================================================================================
setlocal
cd /d C:\thesis\ML_sdfi_fastai2
set PY=..\envs\ML_sdfi\python.exe
set EDA=..\exploratory_data_analysis
set LOG=%EDA%\logs\plan4_queue.log
set BK=%PY% src/ML_sdfi_fastai2/analyse/backup_to_hf.py --repo_id Lasbaskanenmas/befaestelsesdata-spatial-matrix --token_file ..\hftoken_write.txt
set M=../logs_and_models/spatial_matrix/convnext_upernet

findstr /r /c:"^status: LOCKED" "%EDA%\2026-10-06_plan4_declarations.md" >nul || (
  echo The Plan 4 declaration is not LOCKED. Lock it first, see its section 7. Nothing launched.
  exit /b 1
)

echo %date% %time% QUEUE START >> "%LOG%"
call :cell convnext_upernet_ortorgb_ndsm bg
call :cell convnext_upernet_cir bg
call :cell convnext_upernet_ortocir bg
call :cell convnext_upernet_ortocir_ndsm bg
call :cell convnext_upernet_cir_ndsm fg
echo %date% %time% ARMS DONE >> "%LOG%"

echo %date% %time% PICK >> "%LOG%"
%PY% %EDA%\scripts\plan4_pick_production.py --pick > "%EDA%\logs\plan4_pick.log" 2>&1
type "%EDA%\logs\plan4_pick.log"
type "%EDA%\logs\plan4_pick.log" >> "%LOG%"
echo.
echo NEXT: launch C:\thesis\ML_sdfi_fastai2\run_plan4_production.cmd
echo       (it reads the verdict; the declaration says it must START by Mon 12/10 12:00)
goto :eof

REM ---------------------------------------------------------------------------------------------
:cell
set CELL=%~1
echo %date% %time% CELL START %CELL% >> "%LOG%"
call :fold %CELL% 0 || goto :cellfail
call :fold %CELL% 1 || goto :cellfail
call :fold %CELL% 2 || goto :cellfail
echo %date% %time% CELL TRAINED %CELL% >> "%LOG%"
if "%~2"=="bg" (
  start "score %CELL%" /min cmd /c "%EDA%\scripts\plan4_score_cell.cmd %CELL%"
) else (
  call "%EDA%\scripts\plan4_score_cell.cmd" %CELL%
)
exit /b 0
:cellfail
echo %date% %time% CELL FAILED %CELL% -- remaining folds skipped, queue continues >> "%LOG%"
exit /b 1

:fold
echo %date% %time%   train %~1 fold %~2 >> "%LOG%"
%PY% src/ML_sdfi_fastai2/train.py --config configs/matrix_configs/train/%~1_fold%~2.ini || exit /b 1
%BK% --file %M%/%~1_fold%~2/models/%~1_fold%~2.pth --path_in_repo models/%~1_fold%~2.pth
echo %date% %time%   infer %~1 fold %~2 >> "%LOG%"
%PY% src/ML_sdfi_fastai2/infer.py --config configs/matrix_configs/infer/infer_%~1_fold%~2.ini || exit /b 1
exit /b 0
