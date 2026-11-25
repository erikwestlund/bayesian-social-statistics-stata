* 01_fetch.do: download the ELS:2002 public-use file and its documentation
* from NCES
*
* Run from master.do, or on its own from the project folder:
*   do settings.do
*   do do/els/01_fetch.do
*
* By downloading, you accept the NCES data usage agreement: use the data for
* statistical purposes only, make no attempt to identify anyone, and do not
* link it to individually identifiable data.
*
* The data go to inputs/private/raw/els and stay out of git. The NCES
* documentation goes to inputs/public/raw/els_docs, which git also ignores
* because the PDFs are large.
*
* Stata has no SHA-256, so each file is checked with Stata's own checksum
* (CRC) and length. The data catalog in settings.yml records each file's
* SHA-256. A download is checked before it takes its final name, and the
* extracted files are checked too, so an interrupted run leaves nothing
* behind that a later run would trust.
*
* The replicate weights come as a Stata file. The R project reads the SPSS
* copy of the same file; NCES publishes both, with the same values.

local data `"$inputs_private_raw/els"'
local docs `"$inputs_public_raw/els_docs"'

* One file per entry: folder, URL, CRC, length
local files
local files `"`files' `"data https://nces.ed.gov/EDAT/Data/Zip/ELS_2002-12_v1_0_CSV_Datasets.zip 814424038 101722813"'"'
local files `"`files' `"data https://nces.ed.gov/EDAT/Data/Zip/ELS_2002-12_PETS_v1_0_Student_BRR_Stata_Datasets.zip 394215366 171688926"'"'
local files `"`files' `"docs https://nces.ed.gov/pubs2004/2004405.pdf 3602344370 3076889"'"'
local files `"`files' `"docs https://nces.ed.gov/pubs2006/2006344.pdf 1786524095 4269797"'"'
local files `"`files' `"docs https://nces.ed.gov/pubs2006/2006344_4.pdf 444894049 2989113"'"'
local files `"`files' `"docs https://nces.ed.gov/pubs2014/2014364.pdf 2895427292 1296524"'"'

foreach file of local files {
    tokenize `file'
    local folder `"``1''"'
    local url `2'
    if !regexm("`url'", "([^/]+)$") exit 198
    local target `"`folder'/`=regexs(1)'"'
    capture mkdir `"`folder'"'

    capture confirm file `"`target'"'
    if !_rc {
        checksum `"`target'"'
        if r(checksum) != `3' | r(filelen) != `4' {
            display as error `"`target' does not match the NCES file. Delete it and run again."'
            exit 610
        }
        continue
    }

    display as text "Downloading `url'"
    tempfile download
    copy "`url'" `"`download'"'
    checksum `"`download'"'
    if r(checksum) != `3' | r(filelen) != `4' {
        display as error "The download of `url' does not match the NCES file. Run again."
        exit 610
    }
    copy `"`download'"' `"`target'"'
}

* Each zip and the files the series uses from it: name, CRC, length
local archives
local archives `"`archives' `"ELS_2002-12_v1_0_CSV_Datasets.zip els_02_12_byf3stu_v1_0.csv 533714651 383260256 els_02_12_byf1sch_v1_0.csv 1461580987 4880323"'"'
local archives `"`archives' `"ELS_2002-12_PETS_v1_0_Student_BRR_Stata_Datasets.zip els_02_12_byf3stubrr_v1_0.dta 986423707 652376290"'"'

* Extract a zip again unless its files are complete
foreach archive of local archives {
    tokenize `archive'
    local zip `1'
    macro shift
    local complete 1
    local expected `*'
    while "`1'" != "" {
        capture checksum `"`data'/`1'"'
        if _rc | r(checksum) != `2' | r(filelen) != `3' local complete 0
        macro shift 3
    }
    if `complete' continue

    display as text "Extracting `zip'"
    local here `"`c(pwd)'"'
    quietly cd `"`data'"'
    unzipfile "`zip'", replace
    quietly cd `"`here'"'
    tokenize `expected'
    while "`1'" != "" {
        checksum `"`data'/`1'"'
        if r(checksum) != `2' | r(filelen) != `3' {
            display as error `"`data'/`1' does not match the file in the zip."'
            exit 610
        }
        macro shift 3
    }
}

display as text `"ELS:2002 files are in `data', documentation in `docs'"'
