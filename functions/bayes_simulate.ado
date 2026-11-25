*! bayes_simulate: fake students from the regression model
*
* Replaces the data in memory with n fake students. Base-year math is normal
* with mean 51.7 and SD 10. SES is normal with mean 0.08 and SD 0.8 and
* correlates 0.43 with base-year math. These round the values in the HSLS:09
* analysis sample. The follow-up score comes from the regression with the
* given parameters:
*
*   w2_math = alpha + beta1 (w1_math - 50) + beta2 w1_ses + Normal(0, sigma)
*
* simulate() in the Python project's functions/bayes.py does the same.
*
*   bayes_simulate, n(#) alpha(#) beta(# #) sigma(#) clear
program define bayes_simulate
    version 14
    syntax, n(integer) ALPHA(real) BETA(numlist min=2 max=2) SIGMA(real) clear
    clear
    tempname mean sd correlation
    matrix `mean' = (1.7, 0.08)
    matrix `sd' = (10, 0.8)
    matrix `correlation' = (1, 0.43 \ 0.43, 1)
    quietly drawnorm w1_math_c w1_ses, n(`n') means(`mean') sds(`sd') corr(`correlation') double
    local beta1 : word 1 of `beta'
    local beta2 : word 2 of `beta'
    generate double w1_math = w1_math_c + 50
    generate double w2_math = `alpha' + `beta1' * w1_math_c + `beta2' * w1_ses + rnormal(0, `sigma')
    label variable w1_math "Math score, base year (T-score)"
    label variable w1_math_c "Math score, base year, minus 50"
    label variable w1_ses "SES composite"
    label variable w2_math "Math score, first follow-up (T-score)"
end
