*! prior_simulate: simulate outcomes from prior draws
*
* Uses the data prior_draws leaves and replaces it with simulated data: for
* each draw (the first draws(), or all), one outcome y per row of the using
* data, with row numbering those rows and mu the expected outcome. mu() is an
* expression in the parameters and the using data's variables. family():
* normal (needs a sigma parameter), bernoulli (mu on the log-odds scale), or
* poisson (mu on the log scale). simulate_outcomes() in the R and Python
* projects does the same.
*
*   prior_simulate using `students', mu(alpha + beta * parent_ses_z)
program define prior_simulate
    version 14
    syntax using/, MU(string) [FAMily(string) DRAWs(integer 0)]
    if "`family'" == "" local family normal
    if !inlist("`family'", "normal", "bernoulli", "poisson") {
        display as error `"prior_simulate: family() is normal, bernoulli, or poisson, not `family'"'
        exit 198
    }
    if `draws' > 0 quietly keep if draw <= `draws'

    * Number the rows of the using data, then pair every draw with every row
    tempfile draws_file rows
    quietly save `draws_file'
    use `"`using'"', clear
    generate long row = _n
    quietly save `rows'
    use `draws_file', clear
    quietly cross using `rows'
    sort set_id draw row

    generate double mu = `mu'
    if "`family'" == "normal" generate double y = rnormal(mu, sigma)
    if "`family'" == "bernoulli" generate byte y = rbinomial(1, invlogit(mu))
    if "`family'" == "poisson" generate long y = rpoisson(exp(mu))
end
