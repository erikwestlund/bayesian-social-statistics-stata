* 01_fetch_hsls.do: download the HSLS:09 public-use file from NCES and unzip it
*
* Run from master.do, or on its own from the project folder:
*   do settings.do
*   do do/01_fetch_hsls.do
*
* By downloading, you accept the NCES data usage agreement: use the data for
* statistical purposes only, make no attempt to identify anyone, and do not
* link it to individually identifiable data.
*
* Stata has no SHA-256, so the file is checked with Stata's own checksum
* (CRC) and length. Its SHA-256 is
* a4de968eefbac25a2b6f7337931f8c8051ddfcd2fd82920041a3c8abbebbd4aa.

local url "https://nces.ed.gov/EDAT/Data/Zip/HSLS_2016_v1_0_CSV_Datasets.zip"
local crc 3351833931
local length 270598630

local folder `"$inputs_private_raw/hsls"'
local archive `"`folder'/HSLS_2016_v1_0_CSV_Datasets.zip"'
capture mkdir `"`folder'"'

capture confirm file `"`archive'"'
if _rc {
    display as text "Downloading `url' (about 270 MB)"
    copy "`url'" `"`archive'"'
}

checksum `"`archive'"'
if r(checksum) != `crc' | r(filelen) != `length' {
    display as error `"`archive' does not match the NCES file. Delete it and run again."'
    exit 610
}

capture confirm file `"`folder'/hsls_16_student_v1_0.csv"'
if _rc {
    local here `"`c(pwd)'"'
    quietly cd `"`folder'"'
    unzipfile "HSLS_2016_v1_0_CSV_Datasets.zip", replace
    quietly cd `"`here'"'
}

display as text `"HSLS:09 files are in `folder'"'
