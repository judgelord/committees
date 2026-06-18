library(tidyverse)
library(yaml)
library(lubridate)
library(here)

# ---- Extract date from filename ----
get_snapshot_date <- function(path) {
  date_text <- stringr::str_match(
    basename(path),
    "(\\d{4}-\\d{2}-\\d{2})"
  )[, 2]

  if (is.na(date_text)) {
    stop("No YYYY-MM-DD date found in filename: ", path)
  }

  as.Date(date_text)
}

# ---- Convert date to Congress number ----
get_congress <- function(date) {
  year <- lubridate::year(date)

  effective_year <- if_else(
    year %% 2 == 1 & date < as.Date(paste0(year, "-01-03")),
    year - 1L,
    year
  )

  as.integer(floor((effective_year - 1789) / 2) + 1)
}

# ---- Read one YAML file ----
read_committee_membership <- function(path) {
  y <- yaml::read_yaml(path)

  snapshot_date <- get_snapshot_date(path)
  congress <- get_congress(snapshot_date)

  if (!is.list(y) || length(y) == 0) {
    stop("YAML file is empty or not a list: ", path)
  }

  membership <- purrr::imap_dfr(
    y,
    function(members, committee_id) {
      if (is.null(members) || length(members) == 0) {
        return(tibble())
      }

      purrr::map_dfr(members, function(member) {
        as_tibble(member)
      }) |>
        mutate(thomas_id = committee_id)
    }
  )

  membership |>
    mutate(
      snapshot_date = snapshot_date,
      congress = congress,
      source_file = basename(path),
      source_path = path,
      .before = 1
    )
}
# Now make a safe wrapper that skips files that error.
safe_read_committee_membership <- function(path) {
  tryCatch(
    {
      read_committee_membership(path)
    },
    error = function(e) {
      message(
        "Skipping file: ", basename(path),
        "\n  Reason: ", conditionMessage(e)
      )

      tibble()
    }
  )
}
# Then read everything:
  yaml_files <- list.files(
    here("committee-membership-versions"),
    pattern = "^committee-membership-\\d{4}-\\d{2}-\\d{2}(-[a-f0-9]{7,40}).*\\.ya?ml$",
    full.names = TRUE
  ) |>
  sort()

membership_snapshots <- purrr::map_dfr(
  yaml_files,
  safe_read_committee_membership
)

# Save
save(membership_snapshots, file = here("data", "membership_snapshots.rda"))

membership_snapshots |> count(icpsr)

membership_per_congress <- membership_snapshots |>
  distinct(congress, name, bioguide, thomas_id, title, icpsr)

# duplicates
membership_per_congress |> add_count(bioguide, name, thomas_id, congress, sort = T) |> filter(n>1)

save(membership_per_congress, file=  here("data", "membership_per_congress.rda"))
