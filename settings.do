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
global inputs_private_final `"$root/inputs/private/final"'
global inputs_private_intermediate `"$root/inputs/private/intermediate"'
global inputs_private_raw `"$root/inputs/private/raw"'
global inputs_public_final `"$root/inputs/public/final"'
global inputs_public_intermediate `"$root/inputs/public/intermediate"'
global inputs_public_raw `"$root/inputs/public/raw"'
global logs `"$root/logs"'
global notebooks `"$root/notebooks"'
global cache `"$root/outputs/private/cache"'
global outputs_private_notebooks `"$root/outputs/private/notebooks"'
global outputs_private_figures `"$root/outputs/private/figures"'
global outputs_private_reports `"$root/outputs/private/reports"'
global outputs_private_tables `"$root/outputs/private/tables"'
global outputs_public_figures `"$root/outputs/public/figures"'
global outputs_public_reports `"$root/outputs/public/reports"'
global outputs_public_tables `"$root/outputs/public/tables"'
global scratch `"$root/scratch"'

* Create folders that git does not keep (private data, logs, and outputs)
capture mkdir `"$root/do"'
capture mkdir `"$root/docs"'
capture mkdir `"$root/inputs"'
capture mkdir `"$root/inputs/private"'
capture mkdir `"$root/inputs/private/final"'
capture mkdir `"$root/inputs/private/intermediate"'
capture mkdir `"$root/inputs/private/raw"'
capture mkdir `"$root/inputs/public"'
capture mkdir `"$root/inputs/public/final"'
capture mkdir `"$root/inputs/public/intermediate"'
capture mkdir `"$root/inputs/public/raw"'
capture mkdir `"$root/logs"'
capture mkdir `"$root/notebooks"'
capture mkdir `"$root/outputs"'
capture mkdir `"$root/outputs/private"'
capture mkdir `"$root/outputs/private/cache"'
capture mkdir `"$root/outputs/private/figures"'
capture mkdir `"$root/outputs/private/notebooks"'
capture mkdir `"$root/outputs/private/reports"'
capture mkdir `"$root/outputs/private/tables"'
capture mkdir `"$root/outputs/public"'
capture mkdir `"$root/outputs/public/figures"'
capture mkdir `"$root/outputs/public/reports"'
capture mkdir `"$root/outputs/public/tables"'
capture mkdir `"$root/scratch"'

