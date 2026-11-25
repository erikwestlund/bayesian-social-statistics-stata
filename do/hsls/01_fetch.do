* 01_fetch.do: download the HSLS:09 public-use file and its
* documentation from NCES
*
* Run from master.do, or on its own from the project folder:
*   do settings.do
*   do do/hsls/01_fetch.do
*
* By downloading, you accept the NCES data usage agreement: use the data for
* statistical purposes only, make no attempt to identify anyone, and do not
* link it to individually identifiable data.
*
* The data go to inputs/private/raw/hsls and stay out of git. The NCES
* documentation goes to inputs/public/raw/hsls_docs, which git also ignores
* because the PDFs are large.
*
* Stata has no SHA-256, so each file is checked with Stata's own checksum
* (CRC) and length. The data catalog in settings.yml records each file's
* SHA-256. A download is checked before it takes its final name, and the two
* extracted CSV files are checked too, so an interrupted run leaves nothing
* behind that a later run would trust.

local data `"$inputs_private_raw/hsls"'
local docs `"$inputs_public_raw/hsls_docs"'

* One file per entry: folder, URL, CRC, length
local files
local files `"`files' `"data https://nces.ed.gov/EDAT/Data/Zip/HSLS_2016_v1_0_CSV_Datasets.zip 3351833931 270598630"'"'
local files `"`files' `"docs https://nces.ed.gov/surveys/hsls09/pdf/2011328_1.pdf 2276577402 6533607"'"'
local files `"`files' `"docs https://nces.ed.gov/surveys/hsls09/pdf/2011328_2.pdf 629849654 6857638"'"'
local files `"`files' `"docs https://nces.ed.gov/pubs2014/2014361_AppendixI.pdf 1162575862 12336972"'"'
local files `"`files' `"docs https://nces.ed.gov/pubs2018/2018140.pdf 849043046 2277721"'"'

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

* The extracted files: name, CRC, length
local extracted
local extracted `"`extracted' `"hsls_16_student_v1_0.csv 1791336068 796814173"'"'
local extracted `"`extracted' `"hsls_09_school_v1_0.csv 1350199328 2554266"'"'

* Extract the zip again unless both files are complete
local complete 1
foreach file of local extracted {
    tokenize `file'
    capture checksum `"`data'/`1'"'
    if _rc | r(checksum) != `2' | r(filelen) != `3' local complete 0
}
if !`complete' {
    display as text "Extracting HSLS_2016_v1_0_CSV_Datasets.zip"
    local here `"`c(pwd)'"'
    quietly cd `"`data'"'
    unzipfile "HSLS_2016_v1_0_CSV_Datasets.zip", replace
    quietly cd `"`here'"'
    foreach file of local extracted {
        tokenize `file'
        checksum `"`data'/`1'"'
        if r(checksum) != `2' | r(filelen) != `3' {
            display as error `"`data'/`1' does not match the file in the zip."'
            exit 610
        }
    }
}

display as text `"HSLS:09 files are in `data', documentation in `docs'"'
