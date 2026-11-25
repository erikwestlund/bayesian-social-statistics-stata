* 01_fetch.do: download the ELS:2002 public-use files and documentation from NCES
*
* Run from master.do, or on its own from the project folder:
*   do settings.do
*   do do/els/01_fetch.do
*
* By downloading, you accept the NCES data usage agreement: use the data for
* statistical purposes only, make no attempt to identify anyone, and do not
* link it to individually identifiable data.
*
* shared/data_locations.csv lists every file, with its checksum and length. The
* data go under inputs/raw and stay out of git. The documentation
* goes under inputs/raw, which git also ignores because the PDFs are
* large.

fetch_data els
