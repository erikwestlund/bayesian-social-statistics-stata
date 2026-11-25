*! prior_parse: read a prior written as normal(mean, sd), exponential(rate),
*! half_normal(sd), or half_t(df, scale)
*
* plot_priors and prior_interval use it. Returns the prior's display name,
* its density as a Stata expression in x, the central interval holding
* level() percent, its distribution function as an expression in @, its
* highest density (peak), a random draw as an expression (random), its
* central 99.8% (for an axis range), and where
* plot_priors writes the name (label_at, label_y), on the curve's right flank.
*
*   prior_parse normal(0, 0.2)
*   return list
program define prior_parse, rclass
    version 14
    syntax anything(name=prior) [, Level(real 95)]
    local prior = lower(subinstr(`"`prior'"', " ", "", .))
    if !ustrregexm(`"`prior'"', "^(normal|exponential|half_normal|half_t)\(([^,()]+)(,([^,()]+))?\)$") {
        display as error `"prior_parse: write a prior as normal(mean, sd), exponential(rate), half_normal(sd), or half_t(df, scale), not `prior'"'
        exit 198
    }
    local family = ustrregexs(1)
    local a = real(ustrregexs(2))
    local b = real(ustrregexs(4))
    local tail = (100 - `level') / 200

    if "`family'" == "normal" {
        if missing(`a', `b') | `b' <= 0 {
            display as error "prior_parse: normal(mean, sd) needs a mean and a positive sd"
            exit 198
        }
        prior_number `a'
        local a_text `r(text)'
        prior_number `b'
        local name "Normal(`a_text', `r(text)')"
        local density "normalden(x, `a', `b')"
        local lower = invnormal(`tail') * `b' + `a'
        local upper = invnormal(1 - `tail') * `b' + `a'
        local from = invnormal(0.001) * `b' + `a'
        local to = invnormal(0.999) * `b' + `a'
        local label_at = `a' + 1.1 * `b'
        local label_y = normalden(`label_at', `a', `b')
        local peak = normalden(`a', `a', `b')
        local cdf "normal((@ - `a') / `b')"
        local random "rnormal(`a', `b')"
    }
    else if "`family'" == "half_normal" {
        * A normal folded at 0: positive values only, for SDs
        if missing(`a') | `a' <= 0 | !missing(`b') {
            display as error "prior_parse: half_normal(sd) needs one positive sd"
            exit 198
        }
        prior_number `a'
        local name "Half-normal(0, `r(text)')"
        local density "2 * normalden(x, 0, `a')"
        local cdf "max(2 * normal(@ / `a') - 1, 0)"
        local random "abs(rnormal(0, `a'))"
        local lower = `a' * invnormal((1 + `tail') / 2)
        local upper = `a' * invnormal((2 - `tail') / 2)
        local from = 0
        * A folded distribution's quantile p is the unfolded one's (1 + p) / 2
        local to = `a' * invnormal((1 + 0.999) / 2)
        local label_at = 1.2 * `a'
        local label_y = 2 * normalden(`label_at', 0, `a')
        local peak = 2 * normalden(0, 0, `a')
    }
    else if "`family'" == "half_t" {
        * A Student t folded at 0: brms's default for a residual SD is half_t(3, 2.5)
        if missing(`a', `b') | `a' <= 0 | `b' <= 0 {
            display as error "prior_parse: half_t(df, scale) needs a positive df and scale"
            exit 198
        }
        prior_number `a'
        local df_text `r(text)'
        prior_number `b'
        local name "Half-t(`df_text', 0, `r(text)')"
        local density "2 * tden(`a', x / `b') / `b'"
        local cdf "max(2 * t(`a', @ / `b') - 1, 0)"
        local random "`b' * abs(rt(`a'))"
        local lower = `b' * invt(`a', (1 + `tail') / 2)
        local upper = `b' * invt(`a', (2 - `tail') / 2)
        local from = 0
        local to = `b' * invt(`a', (1 + 0.999) / 2)
        local label_at = 0.8 * `b'
        local label_y = 2 * tden(`a', `label_at' / `b') / `b'
        local peak = 2 * tden(`a', 0) / `b'
    }
    else {
        if missing(`a') | `a' <= 0 | !missing(`b') {
            display as error "prior_parse: exponential(rate) needs one positive rate"
            exit 198
        }
        * Stata's exponential functions take the mean (1 / rate), not the rate
        local scale = 1 / `a'
        prior_number `a'
        local name "Exponential(`r(text)')"
        local density "exponentialden(`scale', x)"
        local lower = invexponential(`scale', `tail')
        local upper = invexponential(`scale', 1 - `tail')
        local from = 0
        local to = invexponential(`scale', 0.999)
        local label_at = 0.6 * `scale'
        local label_y = exponentialden(`scale', `label_at')
        local peak = 1 / `scale'
        local cdf "exponential(`scale', max(@, 0))"
        local random "rexponential(`scale')"
    }

    return local family "`family'"
    return local name `"`name'"'
    return local density `"`density'"'
    return local cdf `"`cdf'"'
    return local random `"`random'"'
    return scalar peak = `peak'
    return scalar lower = `lower'
    return scalar upper = `upper'
    return scalar from = `from'
    return scalar to = `to'
    return scalar label_at = `label_at'
    return scalar label_y = `label_y'
end
