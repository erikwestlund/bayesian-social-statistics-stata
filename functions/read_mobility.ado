*! read_mobility: the ELS:2002 students with both SES measures
*
* Loads els_clean, keeps students with family SES (w1_ses, 2002) and adult
* SES (w4_ses, 2012), and adds both standardized: parent_ses_z and
* adult_ses_z, mean 0, SD 1 with the sample SD (n - 1), as in R's sd().
* read_mobility() in the R and Python projects does the same.
*
*   read_mobility, clear
program define read_mobility
    version 14
    syntax, clear
    fw_use inputs.private.final.els_clean, clear
    keep student_id w1_ses w4_ses
    quietly drop if missing(w1_ses, w4_ses)
    foreach pair in "w1_ses parent_ses_z" "w4_ses adult_ses_z" {
        tokenize `pair'
        quietly summarize `1'
        generate double `2' = (`1' - r(mean)) / r(sd)
    }
    label variable parent_ses_z "Family SES, 2002, standardized"
    label variable adult_ses_z "Adult SES, 2012, standardized"
end
