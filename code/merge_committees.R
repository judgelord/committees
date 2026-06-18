###########################################
library(tidyverse)
library(magrittr)


# merge in committee data for the 106th-115th from Stewart and Wu
load(here::here("data", "committees_membership_106-115.rda"))
committees

members_committees <- committees |>
  group_by(icpsr, congress, chamber) |>
  summarise(committees = committees|> unique() |> paste(collapse = ";") |> str_replace_all("\\|", ";"),
            positions = position |> unique() |> paste(collapse = ";")) |>
  ungroup()


# inspect stewart and woon corrected committees
members_committees

members_committees$committees %>% str_split(";") %>% unlist() %>% unique()
members_committees$positions %>% str_split(";") %>% unlist() %>% unique()

# save
save(members_committees, file = here::here("data", "members_committees_106-115th.rda"))

members_committees_sw <- members_committees
################################################################################

# merge in committee data for the 106th-115th from stewart and woon
load(here::here("data", "members_committees_106-115th.rda"))

members_committees

members_committees$committees %>% str_split(";|\\|") %>% unlist() %>% unique()
members_committees$positions %>% str_split(";") %>% unlist() %>% unique()




###########################################################
# merge in new committee data from @unitedstates project
load(here::here("data", "members_committees.rda"))

members_committees_us <-  members_committees

members_committees_us$committees %>% str_split(";") %>% unlist() %>% unique()
members_committees_us$titles %>% str_split(";") %>% unlist() %>% unique()

members_committees_us %<>%
  select(icpsr,
         congress,
         titles,
         committees_unitedstates = committees)


#################################

members_committees <- full_join(members_committees_sw, members_committees_us)


# look where we have overlapping data
look <- members_committees |>
  drop_na(committees, committees_unitedstates) |>
  filter(committees != committees_unitedstates) |>
  count(icpsr, congress, committees, committees_unitedstates)
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
# Because you are also getting a many-to-many join warning, I would first make sure each dataset has only one row per icpsr/congress. You can collapse committees at that level before joining.
members_committees_sw_clean <- members_committees_sw |>
  group_by(icpsr, congress) |>
  summarise(
    committees_sw = normalize_committees(committees),
    positions = paste(positions, collapse  = ";"),
    .groups = "drop"
  )

members_committees_us_clean <- members_committees_us |>
  group_by(icpsr, congress) |>
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






# Now look only at cases where both datasets have data and the normalized committee sets differ:
  look <- members_committees |>
  filter(committees_sw != committees_unitedstates) |>
  arrange(icpsr, -congress)

look |> knitr::kable()

look |> write_csv(file = here::here("data", "discrepancies-between-stewart-and-unitedstates.csv") )

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




save(members_committees, file = here::here("data", "members_committees.rds"))



################################################

#FIXME this requires modified member data from legislators. For example, it assumes state is a chr, not numeric as in voteview
#FIXME 2 can we just merge the committee data without needing member data?
# member_data <- legislators::members |> filter(congress > 105)


members_committees %<>%
  mutate(
    # because these come from two different datasets, need to replace NAs to avoide ifelse below yielding NA
    titles = replace_na(titles, ""), # from @unitedstates data
    positions = replace_na(positions, ""), # from stewart data

    #FIXME with case when so that we preserve NAs
    chair = ifelse( str_detect(titles, "^Chair|;Chair|;Chairman|;Cochairman") | str_detect(positions, "Chair"),
                    1, 0 ),
    ranking_minority = ifelse( str_detect(titles, "Ranking Member")  | str_detect(positions, "Ranking Minority"),
                               1, 0 )
  ) %>%
  # using combined
  #TODO check if this is the right call, maybe they should be combined
  mutate(committees = paste(committees, committees_unitedstates, collapse = ";") |> str_remove("^NA;|NA$"),
         chair = ifelse(is.na(committees), NA, chair ),
         ranking_minority = ifelse(is.na(committees), NA, ranking_minority ) ) %>%
  #select(-committees2) %>%
  distinct()

members_committees

# look where we have overlapping data
look <- members_committees |>
  drop_na(committees, committees_unitedstates) |>
  count(congress, bioname, committees, committees_unitedstates)


# look for missing committee data
missing <- members_committees %>% filter(congress > 105, is.na(committees) | committees == "")

# missing <- members_committees %>% filter(bioname %in% missing$bioname, congress >105) %>% arrange(bioname)

missing

missing %>%
  write_csv(here::here("data", "missing_committees.csv"))

# look for missing committee data
missing <- members_committees %>% filter( is.na(committees) | committees == "")

missing |> count(congress)

missing <- members_committees %>% filter(icpsr %in% missing$icpsr) %>% arrange(icpsr)

missing

missing %>%
  write_csv(here::here("data", "missing_committees.csv"))




members_committees |> count(committees, chair, ranking_minority, sort = T)
members_committees |> count(committees, chair, ranking_minority, congress, sort = T)



## OVERSIGHT

load(here::here("data", "oversight_committee_data.rda"))

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
str_detect(ACUScommittees, mc)


d1$committees |> str_extract_all(mc)

crosswalk <- d1 |>
  mutate(
    committeesACUS = committees,
    committees = committeesACUS |> str_extract_all(mc)) |>
  unnest(committees) |>
  distinct()

members <- members_committees |>
  mutate(committees = str_split(committees, ";|\\|")) |>
  unnest(committees) |>
  distinct() |>
  left_join(crosswalk) |>
  group_by(icpsr,congress, chamber) |>
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

# members %<>%
#   mutate(# drop 0s where we had no oversight data
#     oversight = ifelse(is.na(committees) | committees == "", NA, oversight)) %>%
#   ungroup()

members$committees

# these two should be the same, right?
count(members, oversight, sort = T)
count(members, committees, oversight, sort = T)

look <- count(members, committees, oversight, sort = T)


members_committees_oversight <- members


save(members_committees_oversight, file = here("data", "members_committees_oversight.rda"))


## NOTES ON SOME OF THE MISSING COMMITTEE DATA THAT WAS MISSING
# AMASH switched parties

# Duffy resigned
# CUMMINGS, Elijah Eugene died

# ? CLYBURN, James Enos
# ? MCCARTHY, Kevin


# BISHOP, Dan came in after
# GARCIA, Mike - 2020 special election
# HILL, Katie - resigned
