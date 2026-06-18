# committees

Historical committee membership data from @unitedstates project committee-membership-current.yaml version history


`make_members_committees.R` takes yaml files from the version history of `committee-membership-current.yaml `

It also merges in legislator and committee data from 

- legislators-historical.csv
- committees-historical.csv

`make_stewart_woon_committees_membership_106-115` merges [data from from Stewart and Woon](https://web.mit.edu/cstewart/www/data/data_page.html) 
with voteview.com using the `legislators` R packge, making a large number of corrections <https://web.mit.edu/17.251/www/data_page.html>

`merge_committees.R` merges the two above sources

`make_oversight_committee_data.R` merges this with Lewis and Selin's ACUS oversight jurisdiction data <https://www.vanderbilt.edu/csdi/sourcebook.php>


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

The script creates a directory such as:

```text
committee-membership-versions/
```

and saves one YAML file per relevant Git commit.

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

Including the SHA prevents files from being overwritten when multiple commits occur on the same date.

#### Notes

This script downloads every **committed** version of the file that appears in the repository’s Git history. It does not recover versions that may have existed locally but were never committed.

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
- merges bioguide ids with member names and other information in legislators-historical.csv 
- completes missing ICPSR ids using the `legislators` package <https://github.com/judgelord/legislators>

The combined data include member-congress observations of merged info on members their committees 

"data/members_committees.rda"

# Merge with Stewart and Woon historical committee data 

`code/merge_committees.R` merges Stewart and Woon data. 

The combined data include committee membership and leadership positions

The minimal version of those data are: 

`data/members_committees_combined.rds`


