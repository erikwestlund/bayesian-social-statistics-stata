*! bayes_analysis_sample: the HSLS:09 sample for the Bayesian notebooks
*
* Loads the clean HSLS:09 file and keeps the students with both math scores
* and SES. Adds w1_math_c, base-year math centered at 50, the T-score mean.
* analysis_sample() in the Python project's functions/bayes.py does the same.
*
*   bayes_analysis_sample, clear
program define bayes_analysis_sample
    version 14
    syntax, clear
    fw_use inputs.private.final.hsls_clean_stata, clear
    quietly keep if !missing(w1_math, w2_math, w1_ses)
    generate double w1_math_c = w1_math - 50
    label variable w1_math_c "Math score, base year, minus 50"
end
