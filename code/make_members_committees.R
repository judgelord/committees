
library(tidyverse)
library(here)
library(magrittr)
# load(committees) $ ?


# Install the yaml package if it's not already installed
if (!require("yaml")) {
  install.packages("yaml")
}

# Load the yaml package
library("yaml")

# helper function
extract <- function(x, name){
  d <- map_dfr(x, as_tibble)
  d$thomas_id <- name
  return(d)
}


# y <- here::here("data", "committee-membership-2019-03-28.yaml") |>
#   read_yaml()
#
# names_y <- map(y, names) |> names()
#
# membership2019 <- map2_dfr(y, names_y, extract)
#
#
# y <- here::here("data", "committee-membership-2020-12-07.yaml") |>
#   read_yaml()
#
# names_y <- map(y, names) |> names()
#
# membership2020 <- map2_dfr(y, names_y, extract)
#
#
#
# membership <- full_join(membership2019, membership2020) |>
#   # match the other data from the same source
#   rename(bioguide_id = bioguide)


#TODO DELETE EVERYTHGIN ABOVE QHEN THIS WORKS

here("data", "membership_per_congress.rda") |> load()


y <- here::here("data", "committees-current.yaml") |>
  read_yaml()

committees <- map_dfr(.x = y, .f =  as_tibble)

save(committees, file = here::here("data", "committees_current.rda"))



# JOINT MEMBERSHIP AND COMMITTEE DATA
committee_membership <- left_join(membership_per_congress,
                                        distinct(committees, thomas_id, committee = name, type) ) |>
  # IMPORTANT: drop subcommittees
  drop_na(committee)

save(committee_membership,
     file = here::here("data", "committee_membership.rda") )

# format committee data the same as the Stewart and Woon in the members data
c <- committee_membership |>
  mutate(committee = committee |>
           str_remove_all(".*ommittee on the |.*ommittee on | and.*|,.*|' Affairs| Affairs| Committee|Joint ") |>
           str_to_upper()
  )


if(F){ # TO COMPARE AGAINST OTHER STEWART AND WOON COMMITTEE DATA
  # @unitedstates committee data
  c1 <- c$committee |> unique()

  # Stewart committee data (or whatever is in current member data )
  c2 <- members$committees |> str_split("\\;") |> unlist() |> str_squish() |>  unique()

  # in stewart not in @unitestates (could be old committees )
  c2[!c2 %in% c1]

  # the reverse (could be new committees)
  c1[!c1 %in% c2]
}

count(c, type)

collapse_unique <- function(x, sep = "|") {
  x |>
    unlist(use.names = FALSE) |>
    as.character() |>
    discard(~ is.na(.x) || .x == "NA" || .x == "") |>
    unique() |>
    paste(collapse = sep)
}


members_committees <- c |>
  group_by(bioguide, congress) |>
  summarise(
    name = collapse_unique(na.omit(name)),
    committees = collapse_unique(committee, sep = ";"),
    titles = collapse_unique(title, sep = ";"),
    .groups = "drop"
  ) |>
  add_count(bioguide) |>
  arrange(desc(n))


# INSPECT
members_committees$titles |> str_split(";") |> unlist() |> unique()
members_committees$committees |> str_split(";") |> unlist() |> unique()



# where legislators did not come up with the same bioguide
# members_committees |> filter(bioguide != bioguide_id)
# TODO legislators should return bioguide

legislators_current <- read_csv(here::here("data", "legislators-current.csv"))
legislators_historical <- read_csv(here::here("data", "legislators-historical.csv"))

legislators <- full_join(legislators_current, legislators_historical)

missing_icpsr <- legislators |> filter(is.na(icpsr_id))


# THIS NEEDS TO BE DONE A THE CONGRESS LEVEL
# library(legislators)
# fix <- missing_icpsr |>
#   # adding full name and wikipedia name in case one or the other is ambigious or not matching in legislators
#   mutate(name = paste(full_name, wikipedia_id)) |>
#   extractMemberName("name", congress = 105:119) |>
#   drop_na(icpsr) |>
#   mutate(full_name = str_to_title(full_name))
#
# legislators <- legislators |>
#   left_join(fix |>
#               distinct(icpsr, full_name)) |>
#   mutate(icpsr_id = coalesce(icpsr_id, icpsr)) |>
#   select(-icpsr)

members_committees <- members_committees |>
  mutate(bioguide_id = bioguide) |>
  # has corrected icpsrs
  left_join(legislators)


# look for missing
look <- members_committees |>
  filter(is.na(icpsr_id)) |>
  # adding full name and wikipedia name in case one or the other is ambigious or not matching in legislators
  mutate(name = paste(full_name, wikipedia_id)) |>
  #distinct(congress, name, bioguide,type, state, district) |>
  extractMemberName(col_name = "name", congress = "congress") |>
  filter(is.na(icpsr))

write_csv(look, file = here::here("missing_icpsr.csv"))

look |>
  distinct(congress, district, bioguide, full_name, twitter, wikipedia_id) |>
  filter(district != 0) |>
  arrange(bioguide) |>
  knitr::kable()

# correct missing icpsrs
members_committees <- members_committees |>
  mutate(icpsr_id = ifelse(
    name == "Kelly Loeffler",  41904, icpsr_id
  ))


# missing icpsrs that legislators does match
fix <-  members_committees |>
  filter(is.na(icpsr_id)) |>
  # adding full name and wikipedia name in case one or the other is ambigious or not matching in legislators
  mutate(name = paste(full_name, wikipedia_id)) |>
  #distinct(congress, name, bioguide,type, state, district) |>
  extractMemberName(col_name = "name", congress = "congress") |>
  filter(!is.na(icpsr)) |>
  select(icpsr, bioguide, congress, chamber)

# we this approach uses @unitedstates icpsr coding and seems to avoid issues with party switchers
members_committees %<>% full_join(fix) %>% mutate(icpsr = coalesce(icpsr, icpsr_id))

count(members_committees, name, icpsr, congress, sort = T) |> filter(n>1)

count(members_committees, is.na(icpsr))

save(members_committees, file =  here::here("data", "members_committees.rda"))

## TRYING RUNNING extractMemberName on everything
# this causes party switchers to duplicate
# missing icpsrs that legislators does match
members_committees <-  members_committees |>
  mutate(name = paste(full_name, wikipedia_id)) |>
  extractMemberName(col_name = "name", congress = "congress")

count(members_committees, name, icpsr, congress, sort = T) |> filter(n>1)

count(members_committees, is.na(icpsr))

# save(members_committees, file =  here::here("data", "members_committees.rda"))


