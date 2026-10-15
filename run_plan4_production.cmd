@echo off
REM ==============================================================================================
REM  Great Plan 4, job 6 -- full-pool production retrain of the pick's winner.
REM  Prepared by the assistant, NOT executed by it. The author launches it after run_plan4_queue.cmd
REM  has written results\tables\plan4\pick_verdict.json. Declaration P4: START by Mon 12/10 12:00.
REM
REM  1. read the winner from the verdict (nothing is typed by hand)
REM  2. build its full-pool config pair (plan4_build_configs.py --production)
REM  3. gate it: exactly path_to_valid_txt and job_name differ from the winner's fold-0 config; the
REM     monitor list is the 25 naive tiles, so training sees 19,289 of the 19,314
REM  4. train (last epoch is the model: SaveModelCallback every_epoch, learn.save after fit)
REM  5. back the .pth up to HF
REM  No inference is run (Plan 4 Q8). Log: exploratory_data_analysis\logs\plan4_production.log
REM ==============================================================================================
setlocal
cd /d C:\thesis\ML_sdfi_fastai2
set PY=..\envs\ML_sdfi\python.exe
set EDA=..\exploratory_data_analysis
set LOG=%EDA%\logs\plan4_production.log
set VERDICT=%EDA%\results\tables\plan4\pick_verdict.json

if not exist "%VERDICT%" (echo No pick verdict at %VERDICT%. Run the queue first. & exit /b 1)
for /f "usebackq delims=" %%W in (`%PY% -c "import json;print(json.load(open(r'%VERDICT%'))['winner'].replace('convnext_upernet_',''))"`) do set WIN=%%W
if "%WIN%"=="" (echo Could not read the winner from %VERDICT%. & exit /b 1)
set JOB=convnext_upernet_%WIN%_fullpool
echo %date% %time% production winner: convnext_upernet_%WIN% >> "%LOG%"
echo production winner: convnext_upernet_%WIN%

%PY% %EDA%\scripts\plan4_build_configs.py --production %WIN% --write >> "%LOG%" 2>&1 || (echo config build failed, see %LOG% & exit /b 1)
%PY% %EDA%\scripts\gate_plan4.py --production %WIN% >> "%LOG%" 2>&1 || (echo production gate FAILED, see %LOG% & exit /b 1)
echo %date% %time% train %JOB% >> "%LOG%"
%PY% src/ML_sdfi_fastai2/train.py --config configs/matrix_configs/train/%JOB%.ini || (echo %date% %time% TRAIN FAILED >> "%LOG%" & exit /b 1)
%PY% src/ML_sdfi_fastai2/analyse/backup_to_hf.py --repo_id Lasbaskanenmas/befaestelsesdata-spatial-matrix --token_file ..\hftoken_write.txt --file ../logs_and_models/spatial_matrix/convnext_upernet/%JOB%/models/%JOB%.pth --path_in_repo models/%JOB%.pth >> "%LOG%" 2>&1
echo %date% %time% PRODUCTION DONE %JOB% >> "%LOG%"
echo PRODUCTION DONE: %JOB%
