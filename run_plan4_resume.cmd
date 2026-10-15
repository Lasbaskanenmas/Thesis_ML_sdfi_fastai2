@echo off
REM ==============================================================================================
REM  Great Plan 4 -- RESUME after the 2026-10-07 hang of convnext_upernet_ortorgb_ndsm fold 2.
REM  Prepared by the assistant, NOT executed by it. Use it only if the frozen run cannot be revived
REM  (QuickEdit: press Esc in the old window first).
REM
REM  Before launching:
REM    1. close the old queue window, then make sure no python is left:  nvidia-smi
REM       taskkill /F /IM python.exe /T   (only once no scoring window is working)
REM    2. rename the frozen job folder so the restarted run starts clean (its CSV log appends and
REM       its epoch checkpoints would otherwise mix with the new run's):
REM       ren C:\thesis\logs_and_models\spatial_matrix\convnext_upernet\convnext_upernet_ortorgb_ndsm_fold2 convnext_upernet_ortorgb_ndsm_fold2_hung_20261007
REM    3. turn QuickEdit OFF for this window: title bar -> Properties -> untick QuickEdit Mode
REM
REM  Then: fold 2 of ortorgb_ndsm (folds 0 and 1 are complete and kept), score that cell in the
REM  background, the four remaining cells exactly as in run_plan4_queue.cmd, then the pick.
REM  Log: C:\thesis\exploratory_data_analysis\logs\plan4_queue.log (appended)
REM ==============================================================================================
setlocal
cd /d C:\thesis\ML_sdfi_fastai2
set PY=..\envs\ML_sdfi\python.exe
set EDA=..\exploratory_data_analysis
set LOG=%EDA%\logs\plan4_queue.log
set BK=%PY% src/ML_sdfi_fastai2/analyse/backup_to_hf.py --repo_id Lasbaskanenmas/befaestelsesdata-spatial-matrix --token_file ..\hftoken_write.txt
set M=../logs_and_models/spatial_matrix/convnext_upernet

findstr /r /c:"^status: LOCKED" "%EDA%\2026-10-06_plan4_declarations.md" >nul || (
  echo The Plan 4 declaration is not LOCKED. Nothing launched.
  exit /b 1
)
if exist "C:\thesis\logs_and_models\spatial_matrix\convnext_upernet\convnext_upernet_ortorgb_ndsm_fold2" (
  echo The frozen fold-2 folder is still in place. Rename it first, see step 2 in this file's header.
  exit /b 1
)

echo %date% %time% RESUME START (after fold-2 hang) >> "%LOG%"
call :fold convnext_upernet_ortorgb_ndsm 2 || (
  echo %date% %time% CELL FAILED convnext_upernet_ortorgb_ndsm on resumed fold 2 >> "%LOG%"
  goto :rest
)
echo %date% %time% CELL TRAINED convnext_upernet_ortorgb_ndsm >> "%LOG%"
start "score convnext_upernet_ortorgb_ndsm" /min cmd /c "%EDA%\scripts\plan4_score_cell.cmd convnext_upernet_ortorgb_ndsm"

:rest
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
echo NEXT: launch C:\thesis\ML_sdfi_fastai2\run_plan4_production.cmd  (amended deadline: ~Tue 13/10 00:00)
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
