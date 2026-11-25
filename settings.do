* settings.do: paths for bayesian-social-statistics-stata
*
* fw wrote this file from the project spec. Every do-file refers to folders
* through these globals, so the project runs on any machine without edits.
* settings.yml lists the same folders and holds the rest: the project name,
* the data catalog for fw_use and fw_save, the publishing destinations for
* fw_publish, and the security settings. Framework for Stata (fw_project)
* reads both files. When both set a folder, settings.yml wins: fw_project
* prints a note and lists the folder in r(conflicts). Change a folder here
* and in settings.yml.
*
* Run Stata from the project folder: cd to it first, or open master.do from
* there. The root is set from the current folder every time, because globals
* from another project in the same Stata session would otherwise linger.

global root `"`c(pwd)'"'
capture confirm file `"$root/settings.do"'
if _rc {
    display as error `"settings.do: $root is not the project folder. In Stata, cd to the folder that holds settings.do and master.do, then run the do-file again."'
    exit 601
}

* Folders
global do `"$root/do"'
global docs `"$root/docs"'
global inputs_final `"$root/inputs/final"'
global inputs_intermediate `"$root/inputs/intermediate"'
global inputs_raw `"$root/inputs/raw"'
global logs `"$root/logs"'
global notebooks `"$root/notebooks"'
global cache `"$root/outputs/cache"'
global outputs_notebooks `"$root/outputs/notebooks"'
global outputs_figures `"$root/outputs/figures"'
global outputs_models `"$root/outputs/models"'
global outputs_reports `"$root/outputs/reports"'
global outputs_tables `"$root/outputs/tables"'
global scratch `"$root/scratch"'

* Create the folders git does not keep (data, logs, and outputs)
capture mkdir `"$root/do"'
capture mkdir `"$root/docs"'
capture mkdir `"$root/inputs"'
capture mkdir `"$root/inputs/final"'
capture mkdir `"$root/inputs/intermediate"'
capture mkdir `"$root/inputs/raw"'
capture mkdir `"$root/logs"'
capture mkdir `"$root/notebooks"'
capture mkdir `"$root/outputs"'
capture mkdir `"$root/outputs/cache"'
capture mkdir `"$root/outputs/figures"'
capture mkdir `"$root/outputs/models"'
capture mkdir `"$root/outputs/notebooks"'
capture mkdir `"$root/outputs/reports"'
capture mkdir `"$root/outputs/tables"'
capture mkdir `"$root/scratch"'

