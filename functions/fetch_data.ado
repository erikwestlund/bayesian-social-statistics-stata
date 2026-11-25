*! fetch_data: download and extract the NCES files shared/data_locations.csv lists
*
* fetch_data els      (one data set)
* fetch_data          (every data set)
*
* The file has one row per file: dataset, path (where it goes, relative to
* the project folder), url (where to download it) or from (the zip, another
* row's path, to extract it from), and the file's sha256, crc, and bytes.
* Stata has no SHA-256, so each file is checked with Stata's own checksum
* (crc) and its length (bytes); R and Python check the SHA-256.
*
* A file already in place is checked, not fetched again. A download is
* checked before it takes its final name. An extracted file is checked right
* after the zip is extracted, and a run stops at the first file that does
* not match.
program define fetch_data
    version 14
    args dataset
    local locations shared/data_locations.csv

    preserve
    quietly import delimited using `"$root/`locations'"', clear varnames(1) ///
        stringcols(_all) case(preserve) encoding("utf-8")
    if "`dataset'" != "" {
        quietly keep if dataset == "`dataset'"
        if _N == 0 {
            display as error "`locations' lists no data set `dataset'."
            exit 198
        }
    }
    local rows = _N
    forvalues i = 1/`rows' {
        foreach column in path url from crc bytes {
            local `column'`i' `"`=`column'[`i']'"'
        }
    }
    restore

    forvalues i = 1/`rows' {
        local target `"$root/`path`i''"'
        capture checksum `"`target'"'
        if !_rc & r(checksum) == `crc`i'' & r(filelen) == `bytes`i'' continue

        if `"`url`i''"' != "" {
            capture confirm file `"`target'"'
            if !_rc {
                display as error `"`path`i'' does not match the NCES file. Delete it and run again."'
                exit 610
            }
            display as text `"Downloading `url`i''"'
            tempfile download
            copy `"`url`i''"' `"`download'"'
            checksum `"`download'"'
            if r(checksum) != `crc`i'' | r(filelen) != `bytes`i'' {
                display as error `"The download of `url`i'' does not match the NCES file. Run again."'
                exit 610
            }
            mata: pathsplit(st_local("target"), parent = "", file = ""); st_local("folder", parent)
            capture mkdir `"`folder'"'
            copy `"`download'"' `"`target'"', replace
        }
        else {
            mata: st_local("zip", pathbasename(st_local("from`i'")))
            mata: pathsplit(st_global("root") + "/" + st_local("from`i'"), parent = "", file = ""); st_local("folder", parent)
            display as text `"Extracting `zip'"'
            local here `"`c(pwd)'"'
            quietly cd `"`folder'"'
            capture noisily unzipfile `"`zip'"', replace
            local rc = _rc
            quietly cd `"`here'"'
            if `rc' exit `rc'
            checksum `"`target'"'
            if r(checksum) != `crc`i'' | r(filelen) != `bytes`i'' {
                display as error `"`path`i'' does not match the file in the zip."'
                exit 610
            }
        }
    }
end
