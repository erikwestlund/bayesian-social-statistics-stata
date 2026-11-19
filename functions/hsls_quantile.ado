*! hsls_quantile: quantiles by linear interpolation, as in R and pandas
*
* For probability p and n sorted values, the quantile sits at position
* h = (n - 1) p + 1 and interpolates between the values on either side.
* This is type 7 in R's quantile() and the pandas default. summarize, detail
* and _pctile use a different definition, and centile another.
*
*   hsls_quantile varname, percentiles(numlist)
*   returns r(p#) for each percent, such as r(p5) and r(p50)
program define hsls_quantile, rclass
    version 14
    syntax varname(numeric), PERCentiles(numlist >=0 <=100)
    preserve
    quietly keep if !missing(`varlist')
    sort `varlist'
    local n = _N
    foreach p of local percentiles {
        local h = (`n' - 1) * `p' / 100 + 1
        local low = floor(`h')
        local high = min(`low' + 1, `n')
        return scalar p`p' = `varlist'[`low'] + (`h' - `low') * (`varlist'[`high'] - `varlist'[`low'])
    }
    restore
end
