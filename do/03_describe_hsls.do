* 03_describe_hsls.do: render the HSLS:09 descriptives notebook
*
* notebooks/01-hsls-descriptives.do describes the cleaned file: each
* variable's type and distribution, the sample and its weights, and the
* missing values, their reasons, and their patterns. webdoc runs it and
* writes outputs/private/notebooks/01-hsls-descriptives.html, with the graphs
* embedded. The R and Python projects render the same notebook.
*
* Stata 14 has no dyndoc, so the notebook uses webdoc from SSC, listed under
* packages: in settings.yml. The page shows summaries only, never individual
* records, and stays under private/ because it reads private data.

* The notebook reads the raw student file for the missing-value reasons. It
* has 8,509 variables, more than Stata's default 5,000, and raising the limit
* needs an empty session.
clear all
set maxvar 10000

webdoc do `"$notebooks/01-hsls-descriptives.do"'
