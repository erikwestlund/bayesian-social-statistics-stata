*! bayes_summary: convergence and precision of MCMC draws from several chains
*
* The data in memory hold the draws of all chains, one row per draw, with a
* chain variable and the same number of draws in each chain. For each
* variable in varlist the program computes, as Stan's summary does
* (Vehtari et al., 2021, "Rank-normalization, folding, and localization"):
*
*   mean, sd      over all draws pooled
*   p5, p50, p95  quantiles, interpolated as in R and numpy (type 7)
*   ess_bulk      effective sample size of the rank-normalized draws, with
*                 each chain split in half
*   ess_tail      the smaller ESS of the indicators for the draws at or
*                 below the 5th and at or below the 95th percentile
*   rhat          rank-normalized split R-hat: the larger of the R-hat of the
*                 rank-normalized split chains and of the same for the draws
*                 folded around their median, |x - median|
*   mcse          the Monte Carlo standard error of the mean, sd over the
*                 square root of the ESS of the draws as they are (split
*                 chains, no rank normalization), as Stan computes it
*
* The ESS uses the autocorrelations of all chains together, truncated by
* Geyer's initial monotone sequence, as in Stan and ArviZ.
*
*   bayes_summary varlist, chain(varname) [clear]
*
* Returns r(table), one row per variable. With clear, the summary replaces
* the data in memory, one row per variable, ready for html_table.
program define bayes_summary, rclass
    version 14
    syntax varlist(numeric), CHAIN(varname numeric) [clear]
    if "`clear'" == "" preserve
    sort `chain', stable
    tempname table
    mata: _bayes_summary_st("`varlist'", "`chain'", "`table'")
    matrix rownames `table' = `varlist'
    matrix colnames `table' = mean mcse sd p5 p50 p95 ess_bulk ess_tail rhat
    if "`clear'" != "" {
        clear
        local rows = rowsof(`table')
        quietly set obs `rows'
        quietly generate str32 parameter = ""
        local names : rownames `table'
        forvalues i = 1/`rows' {
            quietly replace parameter = "`: word `i' of `names''" in `i'
        }
        local j 0
        foreach column in mean mcse sd p5 p50 p95 ess_bulk ess_tail rhat {
            quietly generate double `column' = `table'[_n, `++j']
        }
        label variable parameter "Parameter"
        label variable mean "Mean"
        label variable mcse "MCSE"
        label variable sd "SD"
        label variable p5 "5%"
        label variable p50 "50%"
        label variable p95 "95%"
        label variable ess_bulk "Bulk ESS"
        label variable ess_tail "Tail ESS"
        label variable rhat "R-hat"
        format mean mcse sd p5 p50 p95 %9.3f
        format ess_bulk ess_tail %9.0fc
        format rhat %9.3f
    }
    return matrix table = `table'
end

mata:
// Quantile by linear interpolation between sorted values (type 7)
real scalar _bayes_summary_q7(real colvector sorted, real scalar p)
{
    real scalar n, h, low, high
    n = rows(sorted)
    h = (n - 1) * p + 1
    low = floor(h)
    high = min((low + 1, n))
    return(sorted[low] + (h - low) * (sorted[high] - sorted[low]))
}

// The draws of one variable as a matrix: one column per chain
real matrix _bayes_by_chain(real colvector values, real colvector chain)
{
    real colvector ids
    real scalar n, m, c
    real matrix x
    ids = uniqrows(chain)
    m = rows(ids)
    n = rows(values) / m
    if (n != floor(n)) _error(3498, "every chain needs the same number of draws")
    x = J(n, m, .)
    for (c = 1; c <= m; c++) {
        x[., c] = select(values, chain :== ids[c])
    }
    return(x)
}

// Each chain split in half; with an odd number of draws the middle one is dropped
real matrix _bayes_split(real matrix x)
{
    real scalar n, half
    n = rows(x)
    half = floor(n / 2)
    return((x[|1, 1 \ half, .|], x[|n - half + 1, 1 \ n, .|]))
}

// Ranks of the values, ties given their average rank
real colvector _bayes_rank(real colvector v)
{
    real colvector p, s, r
    real scalar n, i, j
    n = rows(v)
    p = order(v, 1)
    s = v[p]
    r = J(n, 1, .)
    i = 1
    while (i <= n) {
        j = i
        while (j < n) {
            if (s[j + 1] != s[i]) break
            j++
        }
        r[p[|i \ j|]] = J(j - i + 1, 1, (i + j) / 2)
        i = j + 1
    }
    return(r)
}

// Rank-normalized draws: normal scores of the pooled ranks
real matrix _bayes_zscale(real matrix x)
{
    real colvector z
    z = invnormal((_bayes_rank(vec(x)) :- 0.375) :/ (rows(x) * cols(x) + 0.25))
    return(colshape(z, rows(x))')
}

// The mean over chains of each chain's autocovariance at a lag, divided by n
real scalar _bayes_acov(real matrix centered, real scalar lag)
{
    real scalar n
    n = rows(centered)
    return(mean(colsum(centered[|1, 1 \ n - lag, .|] :* centered[|lag + 1, 1 \ n, .|])') / n)
}

// Effective sample size of draws in columns, one column per chain
real scalar _bayes_ess(real matrix x)
{
    real scalar n, m, mean_var, var_plus, even, odd, t, max_t, tau, ess
    real rowvector means
    real matrix centered
    real colvector rho
    n = rows(x)
    m = cols(x)
    if (max(x) - min(x) < 1e-15) return(n * m)
    means = mean(x)
    centered = x :- means
    mean_var = mean(colsum(centered :^ 2)') / (n - 1)
    var_plus = mean_var * (n - 1) / n
    if (m > 1) var_plus = var_plus + variance(means')
    rho = J(n, 1, 0)
    rho[1] = 1
    even = 1
    odd = 1 - (mean_var - _bayes_acov(centered, 1)) / var_plus
    rho[2] = odd
    t = 1
    while (t < n - 3 & even + odd > 0) {
        even = 1 - (mean_var - _bayes_acov(centered, t + 1)) / var_plus
        odd = 1 - (mean_var - _bayes_acov(centered, t + 2)) / var_plus
        if (even + odd >= 0) {
            rho[t + 2] = even
            rho[t + 3] = odd
        }
        t = t + 2
    }
    max_t = t - 2
    if (even > 0 & max_t + 2 <= n) rho[max_t + 2] = even
    // Geyer's initial monotone sequence
    t = 1
    while (t <= max_t - 2) {
        if (rho[t + 2] + rho[t + 3] > rho[t] + rho[t + 1]) {
            rho[t + 2] = (rho[t] + rho[t + 1]) / 2
            rho[t + 3] = rho[t + 2]
        }
        t = t + 2
    }
    ess = n * m
    tau = -1 + (max_t >= 0 ? 2 * sum(rho[|1 \ max_t + 1|]) : 0) + (max_t + 2 <= n ? rho[max_t + 2] : 0)
    tau = max((tau, 1 / log10(ess)))
    return(ess / tau)
}

// Potential scale reduction of draws in columns, one column per chain
real scalar _bayes_rhat_basic(real matrix x)
{
    real scalar n, between, within
    n = rows(x)
    between = n * variance(mean(x)')
    within = mean(diagonal(variance(x)))
    return(sqrt((between / within + n - 1) / n))
}

real scalar _bayes_rhat(real matrix x)
{
    real colvector v
    real scalar median
    v = sort(vec(x), 1)
    median = _bayes_summary_q7(v, 0.5)
    return(max((_bayes_rhat_basic(_bayes_zscale(_bayes_split(x))),
        _bayes_rhat_basic(_bayes_zscale(_bayes_split(abs(x :- median)))))))
}

real scalar _bayes_ess_tail(real matrix x)
{
    real colvector v
    real scalar q05, q95
    v = sort(vec(x), 1)
    q05 = _bayes_summary_q7(v, 0.05)
    q95 = _bayes_summary_q7(v, 0.95)
    return(min((_bayes_ess(_bayes_split(x :<= q05)), _bayes_ess(_bayes_split(x :<= q95)))))
}

void _bayes_summary_st(string scalar names, string scalar chainvar, string scalar table)
{
    string rowvector vars
    real colvector chain, v
    real matrix x, result
    real scalar i, ess_bulk, sd
    vars = tokens(names)
    chain = st_data(., chainvar)
    result = J(cols(vars), 9, .)
    for (i = 1; i <= cols(vars); i++) {
        x = _bayes_by_chain(st_data(., vars[i]), chain)
        v = sort(vec(x), 1)
        sd = sqrt(variance(v))
        ess_bulk = _bayes_ess(_bayes_zscale(_bayes_split(x)))
        result[i, .] = (mean(v), sd / sqrt(_bayes_ess(_bayes_split(x))), sd,
            _bayes_summary_q7(v, 0.05), _bayes_summary_q7(v, 0.5), _bayes_summary_q7(v, 0.95),
            ess_bulk, _bayes_ess_tail(x), _bayes_rhat(x))
    }
    st_matrix(table, result)
}
end
