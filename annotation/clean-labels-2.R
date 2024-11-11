library(here)
library(tidyverse)
library(stargazer)
library(caret)
library(scales)
source(here("analysis.R"))

# Load the data
opeds <- read_tsv(here("opeds_aa/aa_opeds.3000a.p.tsv")) %>% mutate(
    year = as.Date(date) %>% year(),
    source = relevel(as.factor(case_when(
        str_detect(source, "Chicago") ~ "Chicago Tribune",
        str_detect(source, "Los Angeles") ~ "Los Angeles Times",
        str_detect(source, "New York") ~ "New York Times",
        str_detect(source, "Wall Street") ~ "Wall Street Journal",
        str_detect(source, "Washington") ~ "The Washington Post",
        TRUE ~ NA
    )), ref = "New York Times")
) %>% select(!c(textfile))
adf.raw.a <- read_tsv(here("annotation/data/prolific.screened.annotations.tsv")) %>%
    mutate(origin = "prolific A") %>%
    mutate(stance5 = ifelse(stance_numeric == 6, NA, stance_numeric)) %>%
    mutate(stance3 = case_when(
        relevance_label %in% c("It is not mentioned.") ~ NA,
        is.na(stance5) ~ NA,
        stance5 == 1 ~ -1,
        stance5 == 2 ~ -0.5,
        stance5 == 3 ~ 0,
        stance5 == 4 ~ 0.5,
        stance5 == 5 ~ 1,
        TRUE ~ 99
    ))
adf.self <- read_tsv(here("annotation/data/self.annotations.100a.tsv")) %>%
    mutate(origin = "self A") %>%
    mutate(stance5 = ifelse(stance_numeric == 6, NA, stance_numeric)) %>%
    mutate(stance3 = case_when(
        is.na(stance5) ~ NA,
        stance5 == 1 ~ -1,
        stance5 == 2 ~ -0.5,
        stance5 == 3 ~ 0,
        stance5 == 4 ~ 0.5,
        stance5 == 5 ~ 1,
        TRUE ~ 0
    ))
adf.raw.b <- read_tsv(here("annotation/data/prolific.pilot100b.annotations.tsv")) %>%
    mutate(origin = "prolific B") %>%
    mutate(
        stance3 = case_when(
            stance_label == "None/Not Discussed" ~ NA,
            stance_label == "Against/Opposes" ~ -0.75,
            stance_label == "In Favor/Supports" ~ 0.75,
            stance_label == "Neutral" ~ 0,
            TRUE ~ 99
        ),
    )

get_failed_coders <- function(df) {
    adf.test <- df %>%
        filter(str_detect(id, "test")) %>%
        mutate(
            test.pass = case_when(
                str_detect(id, "pro") ~ stance3 >= 0.75,
                str_detect(id, "against") ~ stance3 <= -0.75,
                str_detect(id, "neutral") ~ stance3 == 0,
            )
        )
    fails <- adf.test %>% filter(!test.pass)
    adf.test %>%
        group_by(test.pass) %>%
        count()
    fails$coder_id
}
failed_coders <- c(get_failed_coders(adf.raw.a), get_failed_coders(adf.raw.b))
COLS <- c("coder_id", "id", "stance3", "origin")
adf.raw <- adf.raw.a %>%
    select(all_of(COLS)) %>%
    rbind(adf.raw.b %>% select(all_of(COLS))) %>%
    rbind(adf.self %>% select(all_of(COLS))) %>%
    filter(!str_detect(id, "test")) %>%
    mutate(
        coder_quality = !(coder_id %in% failed_coders),
        filename = str_remove_all(id, 'aa_opeds_sample/')
    ) %>% select(!c(id)) %>% left_join(opeds, by='filename')

adf.raw %>% write_tsv(here('annotation/annotator.labels.clean.tsv'))

