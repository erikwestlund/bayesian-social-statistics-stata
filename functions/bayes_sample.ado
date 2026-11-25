*! bayes_sample: sample the regression posterior with bayesmh, several chains
*
* Fits  depvar ~ Normal(alpha + X beta, sigma)  with bayesmh, the random-walk
* Metropolis-Hastings sampler in Stata 14, and saves the draws of all chains
* to one dataset: chain, draw, alpha, beta1, beta2, ..., sigma, and lp, the
* log posterior at the draw. sample() and draws() in the Python project's
* functions/bayes.py do the same with Stan.
*
* Priors, matching stan/regression.stan in the R and Python projects:
*   default    alpha ~ Normal(50, 10), each beta ~ Normal(0, 2.5),
*              sigma ~ Exponential(0.1): the weak priors, bayes.WEAK
*   alpha(m sd) beta(m1 sd1 m2 sd2 ...) sigmarate(#) change them
*   flat       alpha, beta, and log(sigma) flat over the real line: the
*              prior density of sigma is proportional to 1/sigma for
*              positive sigma, so the coefficients' marginal posteriors
*              are the t distributions behind the OLS intervals
*   prioronly  skips the likelihood (bayes_zero_ll), so the draws come from
*              the prior
* The likelihood is normal({sigma}^2): bayesmh takes the variance, and
* writing it as sigma squared keeps sigma as the parameter, so the
* exponential prior applies to sigma as it does in Stan.
*
* Stata 14 runs one chain per bayesmh call, so the program calls bayesmh
* once per chain. Each chain starts at its own random point, drawn as Stan
* draws its starting points: uniform from -2 to 2 for alpha and beta, and
* exp() of a uniform from -2 to 2 for sigma. init(ols) starts every chain at
* the OLS estimates instead. Each chain runs burnin() burn-in iterations,
* then keeps draws() draws, one every thinning() iterations. bayesmh stores
* a draw that repeats the previous one (a rejected proposal) once, with a
* frequency; the saved dataset expands them, so every iteration is a row.
*
*   bayes_sample depvar indepvars [if] [in], saving(filename) [replace
*       flat prioronly alpha(# #) beta(numlist) sigmarate(#) chains(4)
*       burnin(2500) draws(1000) thinning(10) init(random|ols)
*       block(string) adaptation(string) rawsaving(stub) show]
*
* rawsaving(stub) keeps each chain's bayesmh simulation dataset as
* <stub>_chain<#>.dta. show displays bayesmh's output for the first chain.
* Returns r(seconds), r(N), r(chains), r(draws), and r(chain_stats), a matrix
* with each chain's acceptance rate, efficiency (minimum and average), and
* seconds.
program define bayes_sample, rclass
    version 14
    syntax varlist(min=2 numeric) [if] [in], SAVing(string) [REPLACE ///
        FLAT PRIORonly ALPHA(numlist min=2 max=2) BETA(numlist) SIGMArate(real 0.1) ///
        CHAINS(integer 4) BURNin(integer 2500) DRAWS(integer 1000) THINning(integer 10) ///
        INIT(string) BLOCK(string asis) ADAPTation(string) RAWsaving(string) SHOW]

    if "`flat'" != "" & "`prioronly'" != "" {
        display as error "prioronly needs proper priors: drop flat"
        exit 198
    }
    if "`init'" == "" local init random
    if !inlist("`init'", "random", "ols") {
        display as error "init() must be random or ols"
        exit 198
    }
    gettoken depvar predictors : varlist
    local k : word count `predictors'

    * Priors
    if "`alpha'" == "" local alpha 50 10
    if "`beta'" == "" {
        forvalues j = 1/`k' {
            local beta `beta' 0 2.5
        }
    }
    if `: word count `beta'' != 2 * `k' {
        display as error "beta() needs a mean and an SD for each of the `k' predictors"
        exit 198
    }
    if "`flat'" != "" {
        * A log density of -ln(sigma) is a density proportional to 1/sigma. At
        * sigma <= 0 the log is missing, so bayesmh rejects the proposal.
        local priors prior({`depvar':}, flat) prior({sigma}, logdensity(-ln({sigma})))
    }
    else {
        local priors prior({`depvar':_cons}, normal(`: word 1 of `alpha'', `=(`: word 2 of `alpha'')^2'))
        forvalues j = 1/`k' {
            local x : word `j' of `predictors'
            local m : word `=2 * `j' - 1' of `beta'
            local s : word `=2 * `j'' of `beta'
            local priors `priors' prior({`depvar':`x'}, normal(`m', `=`s'^2'))
        }
        * bayesmh's exponential(b) takes the scale b, 1 over the rate
        local priors `priors' prior({sigma}, exponential(`=1 / `sigmarate''))
    }
    if "`prioronly'" != "" local model llevaluator(bayes_zero_ll, parameters({sigma}))
    else local model likelihood(normal({sigma}^2))

    * OLS starting values, when asked for
    marksample touse
    if "`init'" == "ols" {
        quietly regress `depvar' `predictors' if `touse'
        tempname b
        matrix `b' = e(b)
        local ols_sigma = e(rmse)
    }

    tempname stats
    matrix `stats' = J(`chains', 4, .)
    matrix colnames `stats' = arate eff_min eff_avg seconds
    local total 0
    forvalues c = 1/`chains' {
        if "`init'" == "ols" {
            local initial {`depvar':_cons} `=`b'[1, `k' + 1]' {sigma} `ols_sigma'
            forvalues j = 1/`k' {
                local initial `initial' {`depvar':`: word `j' of `predictors''} `=`b'[1, `j']'
            }
        }
        else {
            local initial {`depvar':_cons} `=runiform(-2, 2)' {sigma} `=exp(runiform(-2, 2))'
            forvalues j = 1/`k' {
                local initial `initial' {`depvar':`: word `j' of `predictors''} `=runiform(-2, 2)'
            }
        }
        if "`rawsaving'" != "" local chainfile `"`rawsaving'_chain`c'.dta"'
        else tempfile chainfile
        local options burnin(`burnin') mcmcsize(`draws') thinning(`thinning') ///
            initial(`initial') saving(`"`chainfile'"', replace) dots(0)
        if `"`block'"' != "" local options `options' `block'
        else local options `options' block({sigma})
        if "`adaptation'" != "" local options `options' adaptation(`adaptation')
        timer clear 99
        timer on 99
        quietly bayesmh `depvar' `predictors' if `touse', `model' `priors' `options'
        timer off 99
        if "`show'" != "" & `c' == 1 bayesmh
        quietly timer list 99
        matrix `stats'[`c', 1] = e(arate)
        matrix `stats'[`c', 2] = e(eff_min)
        matrix `stats'[`c', 3] = e(eff_avg)
        matrix `stats'[`c', 4] = r(t99)
        local total = `total' + r(t99)
        local postvars `e(postvars)'
        local parnames `e(parnames)'
        local n = e(N)
        local chainfile`c' `"`chainfile'"'
    }

    * One dataset of draws: rename bayesmh's eq1_p1 ... by the parameter names
    preserve
    local files
    forvalues c = 1/`chains' {
        quietly use `"`chainfile`c''"', clear
        quietly expand _frequency
        sort _index, stable
        generate int chain = `c'
        generate long draw = _n
        local i 0
        local keep chain draw
        foreach v of local postvars {
            local name : word `++i' of `parnames'
            if "`name'" == "sigma" local new sigma
            else if "`name'" == "`depvar':_cons" local new alpha
            else {
                local x : subinstr local name "`depvar':" ""
                local new beta`: list posof "`x'" in predictors'
            }
            rename `v' `new'
            local keep `keep' `new'
        }
        rename _logposterior lp
        local order chain draw alpha
        forvalues j = 1/`k' {
            local order `order' beta`j'
        }
        keep `order' sigma lp
        order `order' sigma lp
        tempfile part`c'
        quietly save `part`c''
    }
    quietly use `part1', clear
    forvalues c = 2/`chains' {
        quietly append using `part`c''
    }
    label variable chain "Chain"
    label variable draw "Draw within the chain"
    label variable alpha "Intercept"
    forvalues j = 1/`k' {
        label variable beta`j' "Slope on `: word `j' of `predictors''"
    }
    label variable sigma "Residual SD"
    label variable lp "Log posterior, up to a constant"
    local priortext = cond("`flat'" != "", "flat", "alpha(`alpha') beta(`beta') sigmarate(`sigmarate')")
    local mu alpha
    forvalues j = 1/`k' {
        local mu `mu' + beta`j' `: word `j' of `predictors''
    }
    char _dta[bayes_model] "`depvar' ~ Normal(`mu', sigma)"
    char _dta[bayes_priors] "`priortext'"
    char _dta[bayes_n] "`n'"
    char _dta[bayes_sampler] "chains(`chains') burnin(`burnin') draws(`draws') thinning(`thinning') init(`init')"
    quietly save `"`saving'"', `replace'
    restore

    return scalar seconds = `total'
    return scalar N = `n'
    return scalar chains = `chains'
    return scalar draws = `draws'
    return matrix chain_stats = `stats'
end
