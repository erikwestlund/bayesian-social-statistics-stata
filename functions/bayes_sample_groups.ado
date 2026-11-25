*! bayes_sample_groups: the regression with an intercept for each group, by bayesmh
*
* Fits  depvar ~ Normal(alpha + a[group] + X beta, sigma),  a ~ Normal(0, tau)
* with bayesmh and saves the draws of all chains to one dataset: chain, draw,
* alpha, beta1, ..., sigma, tau, a1, ..., aJ. stan/regression_groups.stan in
* the R and Python projects is the same model. The priors match it:
* alpha ~ Normal(50, 10), each beta ~ Normal(0, 2.5), sigma ~
* Exponential(0.1), and tau ~ Exponential(taurate()), 0.5 by default.
*
* The group variable must run from 1 to J. form() sets which parameters
* bayesmh samples. Both forms describe the same model:
*
*   offsets  alpha and the offsets a[j] ~ Normal(0, tau), as in the Stan
*            program with centered = 1
*   means    the group means m[j] = alpha + a[j] ~ Normal(alpha, tau), with
*            alpha as their hyperparameter (no constant in the regression);
*            the program saves a[j] = m[j] - alpha
*
* update() sets how bayesmh updates the group parameters:
*
*   block     one random-walk Metropolis-Hastings block for the slopes and
*             all group parameters (and alpha in the offsets form), bayesmh's
*             default for the coefficients of one regression
*   reffects  bayesmh's reffects option: each group parameter in a
*             Metropolis-Hastings block of its own
*   gibbs     the group parameters drawn together from their exact
*             conditional distribution (a Gibbs update), and in the means
*             form alpha too. bayesmh allows this when the likelihood and
*             the prior take variances as parameters, so the model is
*             written with sigma2 and tau2, and the exponential priors on
*             sigma and tau become their densities on the variances
*
* sigma and tau (or sigma2 and tau2) are Metropolis-Hastings blocks of their
* own. Each chain starts alpha, the slopes, and log sigma and log tau at
* uniform draws from -2 to 2, and the group parameters at 0.
*
*   bayes_sample_groups depvar indepvars [if] [in], group(varname)
*       saving(filename) [replace form(offsets|means)
*       update(block|reffects|gibbs) taurate(0.5) chains(4) burnin(2500)
*       draws(1000) thinning(10)]
*
* Returns r(seconds), r(J), and r(chain_stats), as bayes_sample does.
program define bayes_sample_groups, rclass
    version 14
    syntax varlist(min=2 numeric) [if] [in], GROUP(varname numeric) SAVing(string) [REPLACE ///
        FORM(string) UPDate(string) TAUrate(real 0.5) CHAINS(integer 4) BURNin(integer 2500) ///
        DRAWS(integer 1000) THINning(integer 10)]
    if "`form'" == "" local form offsets
    if "`update'" == "" local update block
    if !inlist("`form'", "offsets", "means") {
        display as error "form() must be offsets or means"
        exit 198
    }
    if !inlist("`update'", "block", "reffects", "gibbs") {
        display as error "update() must be block, reffects, or gibbs"
        exit 198
    }
    gettoken depvar predictors : varlist
    local k : word count `predictors'
    marksample touse
    quietly summarize `group' if `touse', meanonly
    local J = r(max)

    * Variances as parameters for Gibbs updates, SDs otherwise
    if "`update'" == "gibbs" {
        local model likelihood(normal({sigma2}))
        local groupvar {tau2}
        local priors prior({sigma2}, logdensity(ln(0.1) - 0.1 * sqrt({sigma2}) - ln(2) - 0.5 * ln({sigma2}))) ///
            prior({tau2}, logdensity(ln(`taurate') - `taurate' * sqrt({tau2}) - ln(2) - 0.5 * ln({tau2})))
        local blocks block({sigma2}) block({tau2})
    }
    else {
        local model likelihood(normal({sigma}^2))
        local groupvar {tau}^2
        local priors prior({sigma}, exponential(10)) prior({tau}, exponential(`=1 / `taurate''))
        local blocks block({sigma}) block({tau})
    }
    local priors `priors' prior({`depvar':`predictors'}, normal(0, 6.25))
    if "`form'" == "offsets" {
        local constant
        local priors `priors' prior({`depvar':_cons}, normal(50, 100)) ///
            prior({`depvar':ibn.`group'}, normal(0, `groupvar'))
        local alpha {`depvar':_cons}
    }
    else {
        local constant noconstant
        local priors `priors' prior({alpha}, normal(50, 100)) ///
            prior({`depvar':ibn.`group'}, normal({alpha}, `groupvar'))
        local alpha {alpha}
    }
    if "`update'" == "reffects" local blocks `blocks' block({`depvar':ibn.`group'}, reffects)
    if "`update'" == "gibbs" {
        local blocks `blocks' block({`depvar':ibn.`group'}, gibbs)
        if "`form'" == "offsets" local blocks `blocks' block({`depvar':_cons `predictors'})
        else local blocks `blocks' block({alpha}, gibbs) block({`depvar':`predictors'})
    }
    else if "`form'" == "means" local blocks `blocks' block({alpha})

    tempname stats
    matrix `stats' = J(`chains', 4, .)
    matrix colnames `stats' = arate eff_min eff_avg seconds
    local total 0
    forvalues c = 1/`chains' {
        local sigma0 = exp(runiform(-2, 2))
        local tau0 = exp(runiform(-2, 2))
        if "`update'" == "gibbs" local initial {sigma2} `=`sigma0'^2' {tau2} `=`tau0'^2'
        else local initial {sigma} `sigma0' {tau} `tau0'
        local initial `initial' `alpha' `=runiform(-2, 2)'
        foreach x of local predictors {
            local initial `initial' {`depvar':`x'} `=runiform(-2, 2)'
        }
        tempfile chainfile`c'
        timer clear 99
        timer on 99
        quietly bayesmh `depvar' `predictors' ibn.`group' if `touse', `constant' `model' `priors' `blocks' ///
            burnin(`burnin') mcmcsize(`draws') thinning(`thinning') initial(`initial') ///
            saving(`"`chainfile`c''"', replace) dots(0)
        timer off 99
        quietly timer list 99
        matrix `stats'[`c', 1] = e(arate)
        matrix `stats'[`c', 2] = e(eff_min)
        matrix `stats'[`c', 3] = e(eff_avg)
        matrix `stats'[`c', 4] = r(t99)
        local total = `total' + r(t99)
        local postvars `e(postvars)'
        local parnames `e(parnames)'
    }

    preserve
    forvalues c = 1/`chains' {
        quietly use `"`chainfile`c''"', clear
        quietly expand _frequency
        sort _index, stable
        generate int chain = `c'
        generate long draw = _n
        local i 0
        foreach v of local postvars {
            local name : word `++i' of `parnames'
            local name : subinstr local name "`depvar':" ""
            if inlist("`name'", "sigma", "tau", "alpha") local new `name'
            else if "`name'" == "sigma2" {
                quietly replace `v' = sqrt(`v')
                local new sigma
            }
            else if "`name'" == "tau2" {
                quietly replace `v' = sqrt(`v')
                local new tau
            }
            else if "`name'" == "_cons" local new alpha
            else if regexm("`name'", "^([0-9]+)b?n?\.") {
                local new = "a" + regexs(1)
            }
            else local new beta`: list posof "`name'" in predictors'
            rename `v' `new'
        }
        local order chain draw alpha
        forvalues j = 1/`k' {
            local order `order' beta`j'
        }
        local order `order' sigma tau
        forvalues j = 1/`J' {
            local order `order' a`j'
            * The means form samples the group means: the offsets are m[j] - alpha
            if "`form'" == "means" quietly replace a`j' = a`j' - alpha
        }
        keep `order'
        order `order'
        tempfile part`c'
        quietly save `part`c''
    }
    quietly use `part1', clear
    forvalues c = 2/`chains' {
        quietly append using `part`c''
    }
    label variable alpha "Intercept"
    label variable sigma "Residual SD"
    label variable tau "SD of the group intercepts"
    char _dta[bayes_sampler] "form(`form') update(`update') chains(`chains') burnin(`burnin') draws(`draws') thinning(`thinning')"
    quietly save `"`saving'"', `replace'
    restore

    return scalar seconds = `total'
    return scalar J = `J'
    return matrix chain_stats = `stats'
end
