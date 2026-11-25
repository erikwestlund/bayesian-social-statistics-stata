*! bayes_interval: the central interval holding a share of the values
*
* The interval runs from the (1 - level)/2 to the (1 + level)/2 quantile.
* Quantiles interpolate linearly between the sorted values, as R's
* quantile() and numpy do by default (type 7), so the ends match
* interval() in the Python project's functions/bayes.py.
*
*   bayes_interval varname [if] [in] [, level(95)]
*   returns r(low), r(high), r(mean), and r(N)
program define bayes_interval, rclass
    version 14
    syntax varname(numeric) [if] [in] [, Level(real 95)]
    marksample touse
    mata: _bayes_interval_st("`varlist'", "`touse'", `level' / 100)
    return scalar low = r(low)
    return scalar high = r(high)
    return scalar mean = r(mean)
    return scalar N = r(N)
end

mata:
real scalar _bayes_quantile7(real colvector sorted, real scalar p)
{
    real scalar n, h, low, high
    n = rows(sorted)
    h = (n - 1) * p + 1
    low = floor(h)
    high = min((low + 1, n))
    return(sorted[low] + (h - low) * (sorted[high] - sorted[low]))
}

void _bayes_interval_st(string scalar name, string scalar touse, real scalar level)
{
    real colvector values
    values = sort(st_data(., name, touse), 1)
    st_rclear()
    st_numscalar("r(low)", _bayes_quantile7(values, (1 - level) / 2))
    st_numscalar("r(high)", _bayes_quantile7(values, (1 + level) / 2))
    st_numscalar("r(mean)", mean(values))
    st_numscalar("r(N)", rows(values))
}
end
