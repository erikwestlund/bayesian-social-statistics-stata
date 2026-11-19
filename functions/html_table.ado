*! html_table: write the data in memory as an HTML table in a webdoc document
*
* Headers are the variable labels, or the names where a variable has no
* label. Numbers use each variable's display format, and missing numbers
* leave the cell empty. Run it outside a webdoc stlog section, so the table
* follows the log in the document.
*
*   html_table [varlist]
program define html_table
    version 14
    syntax [varlist]
    local row "<tr>"
    foreach v of local varlist {
        local text : variable label `v'
        if `"`text'"' == "" local text `v'
        local text : subinstr local text "&" "&amp;", all
        local text : subinstr local text "<" "&lt;", all
        local text : subinstr local text ">" "&gt;", all
        local row `"`macval(row)'<th>`macval(text)'</th>"'
    }
    webdoc put <div class="table"><table>
    webdoc put <thead>`macval(row)'</tr></thead><tbody>
    forvalues i = 1/`=_N' {
        local row "<tr>"
        foreach v of local varlist {
            capture confirm string variable `v'
            if !_rc {
                local text = `v'[`i']
                local text : subinstr local text "&" "&amp;", all
                local text : subinstr local text "<" "&lt;", all
                local text : subinstr local text ">" "&gt;", all
                local row `"`macval(row)'<td>`macval(text)'</td>"'
            }
            else {
                local format : format `v'
                local text = cond(missing(`v'[`i']), "", strtrim(string(`v'[`i'], "`format'")))
                local row `"`macval(row)'<td class="num">`text'</td>"'
            }
        }
        webdoc put `macval(row)'</tr>
    }
    webdoc put </tbody></table></div>
end
