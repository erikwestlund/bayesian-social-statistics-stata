# bayesian-social-statistics-stata

This is a Framework project (Stata). Framework skills for this project are installed for your AI assistant.

Run the whole analysis with `do master.do` from the project folder. Do-files use the path globals set in `settings.do`, such as `$inputs_private_raw`, and never absolute paths.

This project holds restricted data. Do not read or print files in `inputs/private/`, `outputs/private/`. Work from the data dictionary and simulated data instead.

## Project Notes

### Series workflow

This project is a port. Every post is built first in R, Stan, and Quarto (`~/Projects/bayesian-social-statistics-r`), then gets a StatsLab section at lab.phpstats.org. Port a post here only after Erik says the R post and its lab are final. A port reproduces the R notebook's numbers up to Monte Carlo error and follows its outline. `bayesian-social-statistics-r/.agents/skills/series-post/SKILL.md` has the details.

