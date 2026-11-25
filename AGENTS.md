# bayesian-social-statistics-stata

This is a Framework project (Stata). Framework skills for this project are installed for your AI assistant.

Run the whole analysis with `do master.do` from the project folder. Do-files use the path globals set in `settings.do`, such as `$inputs_raw`, and never absolute paths.

This project uses public-use data (HSLS:09 and ELS:2002 from NCES). It is a standard Framework project, not a sensitive one. `.gitignore` keeps the NCES files, the cleaned data, and rendered outputs out of git, and says why for each. Never print individual rows; summaries, models, and figures are fine.

## Project Notes

### Series workflow

This project is a port. Every post is built first in R, Stan, and Quarto (`~/Projects/bayesian-social-statistics-r`), then gets a StatsLab section at lab.phpstats.org. Port a post here only after Erik says the R post and its lab are final. A port reproduces the R notebook's numbers up to Monte Carlo error and follows its outline. `bayesian-social-statistics-r/.agents/skills/series-post/SKILL.md` has the details.

