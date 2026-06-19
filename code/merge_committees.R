###########################################
library(tidyverse)
library(magrittr)


# merge in committee data for the 106th-115th from Stewart and Wu
load(here::here("data", "committees_membership_103-115.rda"))
committees

members_committees_sw <- committees |>
  group_by(icpsr, congress, chamber) |>
  summarise(committees = committees|> unique() |> paste(collapse = ";") |> str_replace_all("\\|", ";"),
            positions = position |> unique() |> paste(collapse = ";")) |>
  ungroup()


# inspect stewart and woon corrected committees
members_committees_sw

members_committees_sw |> count(congress)

members_committees_sw$committees %>% str_split(";") %>% unlist() %>% unique()
members_committees_sw$positions %>% str_split(";") %>% unlist() %>% unique()

################################################################################



###########################################################
# merge in new committee data from @unitedstates project
load(here::here("data", "members_committees.rda"))

members_committees_us <-  members_committees

members_committees_us$committees %>% str_split(";") %>% unlist() %>% unique()
members_committees_us$titles %>% str_split(";") %>% unlist() %>% unique()

# completing icpsrs was done in the make_members_committees.R script, so it should find nothing new here,
# but just checking before deleting missing ICPSRs
library(legislators)
icpsr_misssing <- members_committees_us |>
  filter(is.na(icpsr)) |>
  distinct(congress, bioguide, full_name, wikipedia_id)


icpsr_corrections <- icpsr_misssing |>
  mutate(name = str_c(full_name, wikipedia_id))  |>
  extractMemberName(col_name = "name", congress = "congress") |>
  drop_na(icpsr)

write_csv(icpsr_misssing, file = here::here("data", "unitedstates-legislators-missing-icpsr.csv"))


members_committees_us %<>%
  select(icpsr,
         bioguide,
         congress,
         titles,
         committees_unitedstates = committees) %>%
  distinct()


#################################

# nieve merge before normalizing
members_committees <- full_join(members_committees_sw, members_committees_us)


# look where we have overlapping data
look <- members_committees |>
  drop_na(committees, committees_unitedstates) |>
  filter(committees != committees_unitedstates) |>
  count(icpsr, bioguide, congress, committees, committees_unitedstates)
look


normalize_committees <- function(x, sep = "[;|]") {
  committees <- x |>
    unlist(use.names = FALSE) |>
    as.character() |>
    str_split(sep) |>
    unlist(use.names = FALSE) |>
    str_squish()

  committees <- committees[
    !is.na(committees) &
      committees != "" &
      committees != "NA"
  ]

  if (length(committees) == 0) {
    return(NA_character_)
  }

  committees |>
    unique() |>
    sort() |>
    paste(collapse = ";")
}

# to avoide many-to-many join, collapse committees at member level before joining.
members_committees_sw_clean <- members_committees_sw |>
  group_by(icpsr, congress) |>
  summarise(
    committees_sw = normalize_committees(committees),
    positions = paste(positions, collapse  = ";"),
    .groups = "drop"
  )

members_committees_us_clean <- members_committees_us |>
  group_by(icpsr, congress, bioguide) |>
  summarise(
    committees_unitedstates = normalize_committees(committees_unitedstates),
    titles = paste(titles, collapse  = ";"),
    .groups = "drop"
  )

# Then join:
  members_committees <- full_join(
    members_committees_sw_clean |>
      mutate(positions = str_remove_all(positions, ";Other|Other;|Other|;;") |>
               str_remove_all(";+")
             ),
    members_committees_us_clean,
    by = c("icpsr", "congress")
  )


  ########################################

################## CORRECTIONS


# corrections to committee data
corrections <- read_csv(here::here("data", "committee_corrections_116th.csv"))
corrections

corrections %<>%
  select(-notes, -`...4`) %>%
  # rename committees
  rename(committees_us_correct = committees ) %>%
  distinct(congress, icpsr, committees_us_correct) %>% arrange(icpsr)

corrections

# add in committee data corrections for people in the corrections data\
members_committees <- members_committees %>%
  full_join(corrections)  %>%
  mutate(committees_unitedstates = coalesce(committees_unitedstates, committees_us_correct)) %>%
  select(-committees_us_correct) %>%
  ungroup()


# add hoc corrections, until names are fixed in legislators https://github.com/judgelord/legislators-data/issues/11
members_committees %<>%
  filter(!(icpsr == 22529  & bioguide == "K000402"),
         !(icpsr == 22341  & bioguide == "L000602"),
         !(icpsr == 41110  & bioguide == "L000597"),
         !(icpsr == 21526  & bioguide == "M001221"),
         !(icpsr == 29373  & bioguide == "M001226"),
         !(icpsr == 1110  & bioguide == "L000597")
  )


members_committees %>%
  distinct(bioguide, icpsr) |>
  count(icpsr, sort = T)

members_committees %>%
  distinct(bioguide, icpsr) |>
  count(bioguide, sort = T)


# Now look only at cases where both datasets have data and the normalized committee sets differ:
look <- members_committees |>
  filter(committees_sw != committees_unitedstates) |>
  arrange(icpsr, -congress)

look |> knitr::kable()

look |> write_csv(file = here::here("data", "discrepancies-between-stewart-and-unitedstates.csv") )


save(members_committees, file = here::here("data", "members_committees_combined.rds"))


###################################################################

# TRANSFORMATIONS (PERHAPS MOVE TO A NEW SCRIPT)

################

load(here::here("data", "members_committees_combined.rds"))



################################################


members_committees %<>%
  mutate(
    # because these come from two different datasets, need to replace NAs to avoide ifelse below yielding NA
    titles = replace_na(titles, ""), # from @unitedstates data
    positions = replace_na(positions, ""), # from stewart data
    committees_sw = replace_na(committees_sw, ""),
    committees_unitedstates = replace_na(committees_unitedstates, ""),
    #FIXME with case when so that we preserve NAs
    chair = ifelse( str_detect(titles, "^Chair|;Chair|;Chairman|;Cochairman") | str_detect(positions, "Chair"),
                    1, 0 ),
    ranking_minority = ifelse( str_detect(titles, "Ranking Member")  | str_detect(positions, "Ranking Minority"),
                               1, 0 )
  ) %>%
  # using combined
  #TODO check if this is the right call after investigating discrepencies, issue #1
  mutate(committees = str_c(committees_sw, committees_unitedstates, sep = ";") |>
           str_remove("^;|;$") |>
           str_squish(),
         committees = ifelse(committees == "", NA, committees),
         chair = ifelse(is.na(committees), NA, chair ),
         ranking_minority = ifelse(is.na(committees), NA, ranking_minority ) ) %>%
  #select(-committees2) %>%
  distinct()

members_committees


# look at combined data to make sure it looks right
look <- members_committees |>
  filter(committees_unitedstates != "" & committees_sw != "") |>
  select(starts_with("comm")) |>
  distinct()



members_committees |> count(committees, chair, ranking_minority, sort = T)
members_committees |> count(committees, chair, ranking_minority, congress, sort = T)



## OVERSIGHT

load(here::here("data", "oversight_committee_data.rda"))

oversight_committee_data$`Reporting Committees` |> str_split(";") |> unlist() |> str_squish() |>  unique()

ACUScommittees <- oversight_committee_data$`Reporting Committees` |>
  str_split(";") |>
  unlist() |>
  str_squish() |>
  unique() |>
  str_to_upper()

ACUScommittees

d1 <- oversight_committee_data |> select(
  committees = `Reporting Committees`,
  department_agency_acronym) |>
  drop_na(committees ) |>
  mutate(committees = str_to_upper(committees))# |>
# mutate(committee = str_split(committee, ";") |>
#          str_to_upper() )
# |>  unnest(committee)
d1

members_committees$committees %<>% str_replace_all("\\|", ";")

# CAUTION! THIS WAS WRITTEN WITH "|" rather than ";", causeing errors, I am changing it but it may cause other errors if we are loading thorugh data with "|"
members_committees$committees  <- members_committees$committees |>
  str_replace_all("TURAL RESOURCES", ";NATURAL RESOURCES") |>
  str_replace_all(";NA;", ";" )  |>
  str_remove_all(";NA$|^NA;") |>
  str_replace_na()


m <-  members_committees$committees |>
  str_split("\\;") |>
  unlist() |>
  str_squish() |>
  unique()

m <- m[!m %in% c("0", "NA", NA, "")]
m


#
# match <- function(x,y) {
#   z = ifelse(str_detect(x, y), y, NA)
# }
#
# match2 <- function(y){
#   map_chr(.x = m, )
# }
#
# map_chr(.x = d1$committee, .f = match2 )

mc <- m |> paste(sep = "|", collapse = "|") |> str_remove("^\\|")

# confirm that ACUS committees will be matched to member committees
tibble(
  ACUS_reporting_committee = ACUScommittees,
  in_combined_committee_membership_data = str_detect(ACUScommittees, mc)
) |> knitr::kable()


d1$committees |> str_extract_all(mc)

crosswalk <- d1 |>
  mutate(
    committeesACUS = committees,
    committees = committeesACUS |> str_extract_all(mc)) |>
  unnest(committees) |>
  distinct()

write_csv(crosswalk, file = here::here("data", "ACUS_reporting_committee_crosswalk.csv"))

members_committees_oversight <- members_committees |>
  mutate(committees = str_split(committees, ";|\\|")) |>
  unnest(committees) |>
  distinct() |>
  left_join(crosswalk) |>
  group_by(icpsr,congress) |>
  mutate(committees = str_c( unique(committees), collapse = ";")  |>
           str_remove_all("^NA;|;NA$|^NA$") |>
           str_replace(";NA;", ";"),
         #oversight = str_c( unique(department_agency_acronym), collapse = ";"),
         oversight = list(department_agency_acronym)  |>
           unlist() |> paste(collapse  = ";") |>
           str_remove_all("^NA;|;NA$|^NA$") |>
           str_replace(";NA;", ";")
  ) |>
  select(-department_agency_acronym, -committeesACUS) |>
  ungroup() |>
  distinct()

# look at combined data to make sure it looks right
look <- members_committees_oversight |>
  filter(committees_unitedstates != "" & committees_sw != "") |>
  select(starts_with("comm")) |>
  distinct()


members_committees_oversight$committees

# these two should be the same, right?
count(members_committees_oversight, oversight, sort = T)
count(members_committees_oversight, committees, oversight, sort = T)

look <- count(members_committees_oversight, committees, oversight, sort = T)

look <- members_committees_oversight |> filter(is.na(oversight))


## NOTES ON SOME OF THE MISSING COMMITTEE DATA THAT WAS MISSING
# AMASH switched parties

# Duffy resigned
# CUMMINGS, Elijah Eugene died

# ? CLYBURN, James Enos
# ? MCCARTHY, Kevin


# BISHOP, Dan came in after
# GARCIA, Mike - 2020 special election
# HILL, Katie - resigned



# add hoc corrections, until names are fixed in legislators https://github.com/judgelord/legislators-data/issues/11
members_committees_oversight %<>%
  filter(!(icpsr == 22529  & bioguide == "K000402"),
         !(icpsr == 22341  & bioguide == "L000602"),
         !(icpsr == 41110  & bioguide == "L000597"),
         !(icpsr == 21526  & bioguide == "M001221"),
         !(icpsr == 29373  & bioguide == "M001226"),
         !(icpsr == 1110  & bioguide == "L000597")
  )

save(members_committees_oversight, file = here::here("data", "members_committees_oversight.rda"))


#TODO LOOK FOR MISSINGNESS BY MERGING WITH VOITEVIEW
#FIXME merging with voteview here requires modified member data from legislators. For example, it assumes state is a chr, not numeric as in voteview
#FIXME 2 can we just merge the committee data without needing member data?
members <- legislators::members |> filter(congress > 102)

members %<>% left_join(members_committees_oversight)


# confirm no duplicates in member_data post merge
members <- distinct(members)
dim(members)
members |> add_count(bioname, icpsr, chamber, congress, sort = T) |> filter(n>1, bioguide_id != bioguide) |>
  # left_join(members_committees |> select(bioguide, name)) |>
  distinct(chamber, congress, bioname,
           #name_incorrect = name,
           icpsr, bioguide_correct = bioguide_id, bioguide_incorrect = bioguide) |>
  knitr::kable()


# look for missing committee data
missing <- members %>%
  filter(congress > 102,
         state_abbrev != "USA",
         is.na(committees) | committees == ""| committees == ";") |>
  left_join(icpsr_misssing |> select(congress, bioguide_id = bioguide) |>  mutate(icpsr_missing = T)) |>
  mutate(icpsr_missing =  replace_na(icpsr_missing, F) )

# missing <- members_committees %>% filter(bioguide %in% missing$bioguide, congress >105) %>% arrange(bioguide)

missing

missing %>%
  filter(icpsr_missing == FALSE) |>
  select(chamber, congress, bioname, icpsr, state, bioguide_id, icpsr_missing) %>%
  write_csv(here::here("data", "missing_committees.csv"))

missing %>%
  filter(icpsr_missing) |>
  select(chamber, congress, bioname, icpsr, state, bioguide_id, icpsr_missing) %>%
  knitr::kable()

missing |> count(congress)

missing %>%
  write_csv(here::here("data", "missing_committees.csv"))

# all congresses for members swith one or more missing
missing_with_nonmissing <- members %>%
  filter(icpsr %in% missing$icpsr) %>%
  select(chamber, congress, bioname, icpsr, state, bioguide_id, positions, titles, starts_with("committ")) %>%
  arrange(icpsr)

missing_with_nonmissing

missing_with_nonmissing %>%
  write_csv(here::here("data", "missing_with_nonmissing.csv"))




