*! prior_stats: statistics of each simulated data set
*
* Uses the data prior_simulate leaves and replaces it with one row per set
* and draw. The statistics are written as for collapse, such as
* (sd) outcome_sd = y or (mean) share_one = y. simulated_stats() in the R and
* Python projects does the same.
*
*   prior_stats (sd) outcome_sd = y
program define prior_stats
    version 14
    syntax anything(name=stats equalok)
    local labels : value label set_id
    collapse `stats', by(set_id draw)
    label values set_id `labels'
end
