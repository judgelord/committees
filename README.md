# committees

Historical committee membership data from @unitedstates project committee-membership-current.yaml version history

A minimal version of combined data described below, including committee membership and leadership positions, is in the data folder: 

## `data/members_committees_combined.rda`

More detailed versions of these data can be reproduced with the code in this repository: 

- `download_committee_membership_versions.sh` collects yaml files from the version history of `committee-membership-current.yaml `

- `combine_yaml.R` combines them into a single historical committee membership dataset.

- `make_members_committees.R` merges in other legislator and committee data from the @unitedstates project

  - legislators-historical.csv
  - committees-historical.csv

It also completes missing ICPSR IDs using the [`legislators` R package](https://judgelord.github.io/legislators/)

- `make_stewart_woon_committees_membership_103-115` merges [data from from Stewart and Woon](https://web.mit.edu/cstewart/www/data/data_page.html), making a number of corrections <https://web.mit.edu/17.251/www/data_page.html>

- `merge_committees.R` merges the two above sources

- `make_oversight_committee_data.R` merges this with Lewis and Selin's ACUS oversight jurisdiction data <https://www.vanderbilt.edu/csdi/sourcebook.php> 

This README describes the workflow, data, and requested citation. 

# Committee Membership Historical Snapshots from @united-states/legislators 

This project creates a historical record of U.S. congressional committee membership using archived versions of the `committee-membership-current.yaml` file from the [`unitedstates/congress-legislators`](https://github.com/unitedstates/congress-legislators) GitHub repository.

The workflow has two main steps:

1. Download historical versions of the YAML file from Git history.
2. Combine those YAML snapshots into a single tabular dataset.

## Scripts

### `download_committee_membership_versions.sh`

Downloads every committed version of:

```text
committee-membership-current.yaml
```

from the GitHub repository:

```text
https://github.com/unitedstates/congress-legislators
```

The script uses `git log` to identify commits that modified the file and `git show` to save the version of the file at each commit.

#### Usage

From the project directory, run:

```bash
bash download_committee_membership_versions.sh
```

#### Output

The script creates a directory:

```text
committee-membership-versions/
```

and saves one YAML file per Git commit.

Example output files:

```text
committee-membership-versions/
  committee-membership-2019-03-28-a1b2c3d.yaml
  committee-membership-2020-12-07-e4f5g6h.yaml
  committee-membership-2021-03-03-b9ef418.yaml
```

Each filename includes:

- the commit date, in `YYYY-MM-DD` format
- the short Git commit SHA

---

### `combine_yaml.R`

Reads the downloaded YAML snapshot files and combines them into a single historical committee membership dataset.

The script:

- finds all saved committee membership YAML files
- extracts the snapshot date from each filename
- calculates the Congress number from the snapshot date
- reads committee membership data from each YAML file
- adds source metadata such as the filename and path
- combines all valid snapshots into one data frame
- skips malformed YAML files when they cannot be read

Some historical snapshots contain YAML formatting problems, such as duplicate map keys. These files are skipped because there are many available snapshots and the project does not require every single version.

#### Usage

Run the script from R or RStudio:

```r
source("combine_yaml.R")
```

or from the command line:

```bash
Rscript combine_yaml.R
```

#### Main output

The main object created by the script is:

```r
membership_snapshots
```

This is a combined data frame with one row per observed committee membership in a given snapshot.

Important columns include:

| Column | Description |
|---|---|
| `snapshot_date` | Date of the Git commit, extracted from the YAML filename |
| `congress` | Congress number inferred from `snapshot_date` |
| `source_file` | Name of the YAML file used for that observation |
| `source_path` | Full path to the YAML file |
| `thomas_id` | Committee identifier from the YAML structure |
| `bioguide_id` | Member Bioguide ID, renamed from `bioguide` when present |
| other columns | Additional fields from the original YAML data, such as name, party, rank, or title when available |


## Data created

### Raw YAML snapshots

Directory:

```text
committee-membership-versions/
```

or, depending on local configuration:

```text
data/committee-membership-versions/
```

These files are direct exports of historical versions of `committee-membership-current.yaml` from GitHub.

Example:

```text
committee-membership-2021-03-03-b9ef418.yaml
```

The date in the filename is used as the snapshot date. The short SHA identifies the exact Git commit.

---

### Combined membership snapshots

The combined dataset contains committee membership observations stacked across all readable snapshots.


```text
data/membership_snapshots.rda
```

# Merge in committee names and legislator metadata + complete missing ICPSR ids 

`code/make_members_committees.r` 

- merges committee codes with committee names from committees-current.yaml
- merges bioguide IDs with member names and other information in legislators-historical.csv 
- completes missing ICPSR IDs using the `legislators` package <https://github.com/judgelord/legislators> to get ICPSRs from the "full_name"

The combined data include member-congress observations of merged info on members and their committees. 

"data/members_committees.rda"

# Merge with [Stewart and Woon historical committee data](https://web.mit.edu/17.251/www/data_page.html#2)

`code/make_stewart_woon_committees.R` makes several hundred corrections to the Stewart and Woon data.^[Charles Stewart III and Jonathan Woon. Congressional Committee Assignments, 103rd to 114th Congresses, 1993--2017: House of Representatives, 2017]

>  These data are made available for academic use, but may not be used commercially.

`code/merge_committees.R` merges @unitedstates and Stewart and Woon data.


The combined data include committee membership and leadership positions.

The minimal version of those data is: 

`data/members_committees_combined.rda`


# Citation

Because they are a composite, these data require at least three citations: 

1. Devin Judge-Lord. 2026. "Congressional Committee Assignments and Leadership Positions, 103th to 119th Congresses, 1993--2026"

2. Charles Stewart III and Jonathan Woon. 2017. "Congressional Committee Assignments, 103rd to 114th Congresses, 1993--2017"

3. @unitedstates-project, 2026. “Unitedstates/Congress-Legislators.” <https://github.com/unitedstates/congress-legislators>. Date Accessed: June 19, 2026.

If you are using code to pull in additional variables from Lewis and Selin (2012) or voteview.com, you should cite them as well. 

# References

Devin Judge-Lord, Eleanor Neff Powell, and Justin Grimmer. 2025. “The Effects of Shifting Priorities and Capacity on Elected Officials’ Policy Work and Constituency Service: Evidence from a Census of Legislator Requests to U.S. Federal Agencies, Replication Data.” *American Journal of Political Science*. Harvard Dataverse Network, at: <https://doi.org/10.7910/DVN/LWOCW>.

Lewis, David E., and Jennifer L. Selin. 2012. *<span class="nocase">ACUS Sourcebook of United States Executive Agencies</span>*. Administrative Conference of the United States.

Lewis, Jeffrey B., Keith Poole, Howard Rosenthal, Adam Boche, Aaron Rudkin, and Luke Sonnet. 2026. “Voteview: Congressional Roll-Call Votes Database.” <https://voteview.com>. Date Accessed: June 19, 2026.

Stewart, Charles III, and Jonathan Woon. 2017. “Congressional Committee Assignments, 103rd to 115th Congresses, 1993–2017: House of Representatives.” <https://web.mit.edu/17.251/www/data_page.html#2>. Date Accessed: March 18, 2025.

@unitedstates-project, the. 2026. “Unitedstates/Congress-Legislators.” <https://unitedstates.github.io/> <https://github.com/unitedstates/congress-legislators>. Date Accessed: June 19, 2026.
