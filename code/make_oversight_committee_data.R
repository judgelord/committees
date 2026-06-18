library(tidyverse)
library(magrittr)
library(here)
library(googlesheets4)


# https://www.vanderbilt.edu/csdi/sourcebook.php
d <- here("data", "ACUS0413.csv") |>
  read_csv() |>
  drop_na(Agency)



master_crosswalk <- read_sheet("1lxKi3EsOREE-YoOjPE6nIxzwfyJJYbao2YUji__UR7c") |>
  drop_na(department_agency_acronym)

master_crosswalk %<>% mutate(ACUS_agency = coalesce(ACUS_agency, agency),
                             ACUS_agency = ifelse(ACUS_agency %in% d$Agency, ACUS_agency, NA))

master_crosswalk

d <- left_join(d, master_crosswalk |> select(ACUS_agency, department_agency_acronym),
               by =join_by(Agency == ACUS_agency))

d |> select(ACUS_agency = Agency, department_agency_acronym) |>
  filter(is.na(department_agency_acronym)) |>
  head(15)

d$department_agency_acronym


oversight_committee_data <- d


save(oversight_committee_data, file = here::here("data", "oversight_committee_data.rda"))

load(here::here("data", "oversight_committee_data.rda"))
