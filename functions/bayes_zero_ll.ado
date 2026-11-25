*! bayes_zero_ll: a log likelihood of 0, for sampling from the prior
*
* bayesmh needs a likelihood. bayes_sample, prioronly passes this evaluator
* to bayesmh's llevaluator() option: it ignores the data and returns 0, so
* the posterior bayesmh samples is the prior.
program define bayes_zero_ll
    version 14
    args lnf xb
    scalar `lnf' = 0
end
