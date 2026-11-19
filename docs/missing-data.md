# HSLS:09 missing data

HSLS:09 records missing values as reserve codes, almost all negative. The
cleaning scripts sort the codes into two groups, because an analysis treats
them differently.

- **Logical skip** (−7, −6). The question did not apply. Parent 2 education
  is skipped in a one-parent family. Math self-efficacy is skipped for a
  student with no fall 2009 math class. These students are outside the
  population the question describes. An analysis of that variable usually
  drops them.
- **Nonresponse** (every other reserve code). The question applied and the
  value is unknown. Most often the student or parent skipped the item or did
  not complete the survey. Two codes come from the study itself: −4 marks an
  item left off the abbreviated interview, and −5 marks a value NCES
  suppressed on the public-use file. An analysis imputes these values or
  models them.

The two groups are this project's handling rules, built on the NCES code
definitions below. The cleaning scripts turn both into missing values. For
the gates that matter in this series, a flag records which group applies.

## Reserve codes

The codes come from table 38 of the second follow-up documentation (NCES
2018-140). NCES's response-rate tables also count −6 and −7 as "not
applicable" and the other codes as "item missing."

| Code | Meaning | Kind |
|---|---|---|
| −1 | Don't know | Nonresponse |
| −3 | Carry-through missing: an earlier gate question went unanswered | Nonresponse |
| −4 | Not administered in the abbreviated interview | Nonresponse |
| −5 | Suppressed on the public-use file | Nonresponse |
| −6 | Survey component not applicable, such as a parent outside the subsample | Logical skip |
| −7 | Item not applicable, given an earlier answer | Logical skip |
| −8 | Unit nonresponse: the whole survey is missing | Nonresponse |
| −9 | Item nonresponse | Nonresponse |

## Crosswalk columns

`inputs/public/raw/hsls_crosswalk.csv` lists each variable's codes by kind.
The R, Python, and Stata projects keep identical copies.

- `missing` lists nonresponse codes. A code set comes from the variable's
  NCES value labels. Some positive codes also mean nonresponse, such as 98
  and 99 on parent occupation.
- `skip` lists logical-skip codes.
- `derive` = `applies` builds a 0/1 flag from the source variable. A logical
  skip gives 0 and an answer gives 1. Nonresponse gives a missing value.
- `fill` reads `<name>=<value>`. Where the variable is still missing and the
  named variable is observed, it takes that value.
- `within` names a flag. The variable is missing wherever that flag is not 1.

## Flags

| Flag | Source | 0 means |
|---|---|---|
| `w1_responded` | `X1SQSTAT` | No base-year student survey (2,059) |
| `w1_parent_responded` | `X1PQSTAT` | No base-year parent survey (6,715) |
| `w2_responded` | `X2SQSTAT` | No first follow-up student survey (2,909) |
| `w1_math_class` | `S1MFALL09` | No math class in fall 2009 (2,113) |
| `w1_two_parents` | `X1P2RELATION` = −7 | One parent or guardian in the household (3,619) |
| `w1_parent1_worked` | `X1PAR1EMP` = 1 | Parent 1 never worked for pay (551) |
| `w1_parent2_worked` | `X1PAR2EMP` = 1 | Parent 2 never worked for pay (419). Missing without a second parent |

`w1_two_parents` comes from parent 2's relationship to the student. It has a
value for 4 students whose parent 2 education is missing.

The worked flags come from employment status: 1 ("never worked for pay")
gives 0, and 2–4 (not working now, part time, full time) give 1. Where
employment status is missing and the parent's occupation is known, the flag
is 1 (18 parent 1 and 15 parent 2 cases). An occupation coded 99
("Uncodeable") is missing in the occupation variable.

`w1_math_class` comes from the gate question `S1MFALL09`, not from
`X1MTHEFF`. On `X1MTHEFF`, −9 covers two cases. For 402 students, the gate
answer was yes and some scale items went unanswered. For 170 students, the
gate question itself went unanswered.

## Patterns in the student file

- **Survey response.** The base-year math score, SES, and math
  self-efficacy are −8 for the 2,059 students without a base-year student
  survey, and each of them has a base-year student weight of 0. Other
  variables can still have values for them. Sex is recorded for 2,053, race
  for 1,053, and parent 1 education for 355.
- **Parent response.** The parent education, occupation, and income
  components are −8 for the 6,715 students whose parent did not respond.
- **Panel students.** The 18,623 students with both math scores and SES are
  exactly the students with a panel weight `W2W1STU` above 0.
- **Labeled codes only.** The SES composite and the self-efficacy scale have
  real negative values. 10,863 students have SES below 0. Only the codes in
  the crosswalk become missing.
- **Code meanings by wave.** The base-year documentation (NCES 2011-328)
  defines −8 as "nonrespondent or component not applicable." The second
  follow-up splits that meaning between −8 and −6. On base-year variables, −8
  can mean either.
- **Meanings of −1.** −1 means "Don't know" on most items. On 89 transcript
  variables, such as credits in English (`X3TCREDENG`), the NCES value labels
  give −1 as "Did not attempt" or "Did not attempt credit," which is an
  answer.
- **Positive codes.** Several items use positive codes for "Don't know," such
  as 11 on base-year educational expectations (`X1STUEDEXPCT`) and 13 on the
  first follow-up version (`X2STUEDEXPCT`). Parent occupation uses 98 ("Don't
  know") and 99 ("Uncodeable"). New crosswalk rows need a check of each
  variable's labels.

## SES imputation

`X1SES` is built from five parent components: both parents' education, both
parents' occupational prestige, and family income. The SES composite has
three cases.

- **Parent responded with all components** (`X1SES_IM` = 0). SES is computed
  directly.
- **Parent responded with some components imputed** (`X1SES_IM` = 2). NCES
  imputed the missing components once.
- **Parent did not respond** (`X1SES_IM` = 1, about 23% of base-year
  respondents). NCES drew five multiple imputations, `X1SES1`–`X1SES5`.
  `X1SES` is their mean.

The mean of the imputations is shrunk toward the center and carries no
imputation uncertainty. Using it as observed data understates the standard
errors. Analyses should use the five imputations or model SES directly.

`X1SES_IM` is 1 for 160 students without a base-year student survey, whose
SES is missing. The cleaned `w1_ses_imputed` is missing for every student
without a base-year student survey.

## Sources

The fetch scripts download these PDFs to `inputs/public/raw/hsls_docs/`. The
data catalog lists each one with its SHA-256. `docs/codebook.md` covers the
variables this series uses.

- [HSLS:09 Base-Year to Second Follow-Up Data File Documentation (NCES 2018-140)](https://nces.ed.gov/pubs2018/2018140.pdf).
  Section 7.4, table 38: reserve codes.
- [HSLS:09 Base-Year Data File Documentation (NCES 2011-328), volume 1](https://nces.ed.gov/surveys/hsls09/pdf/2011328_1.pdf).
  Section 8.1.5: base-year reserve codes. Section 7.3: imputation.
  Appendix F: composite variables. Appendix J: SES.
- [HSLS:09 base-year codebooks (NCES 2011-328, appendix K)](https://nces.ed.gov/surveys/hsls09/pdf/2011328_2.pdf)
- [HSLS:09 base-year to first follow-up codebooks (NCES 2014-361, appendix I)](https://nces.ed.gov/pubs2014/2014361_AppendixI.pdf)
- [HSLS:09 user manuals](https://nces.ed.gov/surveys/hsls09/usermanuals.asp)
