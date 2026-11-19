*! hsls_weighted_mean_sd: weighted mean and population SD of a variable
*
* Uses the cases where the variable and the weight are present and the
* weight is above 0. The SD divides by the sum of the weights, as
* weighted_mean_sd() does in Python. summarize with aweights gives the same
* mean, but its variance rescales the weights to sum to N and divides by
* N - 1.
*
*   hsls_weighted_mean_sd varname, weightvar(varname)
*   returns r(mean), r(sd), and r(N)
program define hsls_weighted_mean_sd, rclass
    version 14
    syntax varname(numeric), WEIGHTvar(varname numeric)
    marksample touse
    quietly replace `touse' = 0 if missing(`weightvar') | `weightvar' <= 0
    quietly summarize `varlist' [aweight = `weightvar'] if `touse', meanonly
    local mean = r(mean)
    local n = r(N)
    tempvar square
    quietly generate double `square' = (`varlist' - `mean')^2 if `touse'
    quietly summarize `square' [aweight = `weightvar'] if `touse', meanonly
    return scalar mean = `mean'
    return scalar sd = sqrt(r(mean))
    return scalar N = `n'
end
