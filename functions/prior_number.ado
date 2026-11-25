*! prior_number: a number as it appears in a prior's name
*
* Like R's %g: 0.2, not Stata's .2. prior_parse uses it.
*
*   prior_number 0.2
*   display r(text)
program define prior_number, rclass
    version 14
    args value
    local text = strtrim(string(`value', "%12.0g"))
    if substr("`text'", 1, 1) == "." local text "0`text'"
    if substr("`text'", 1, 2) == "-." local text = "-0" + substr("`text'", 2, .)
    return local text "`text'"
end
