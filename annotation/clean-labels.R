library(here)
library(tidyverse)
library(stargazer)
library(caret)
library(scales)
source(here("analysis.R"))

prep_annotator_labels <- function() {
    # Load the data
    opeds <- read_tsv(here("opeds_aa/aa_opeds.3000a.p.tsv")) %>% mutate(
        id = paste0("aa_opeds_sample/", `filename`),
        year = as.Date(date) %>% year(),
        parent_source = relevel(as.factor(case_when(
            str_detect(source, "Chicago") ~ "Chicago Tribune",
            str_detect(source, "Los Angeles") ~ "Los Angeles Times",
            str_detect(source, "New York") ~ "New York Times",
            str_detect(source, "Wall Street") ~ "Wall Street Journal",
            str_detect(source, "Washington") ~ "The Washington Post",
            TRUE ~ NA
        )), ref = "New York Times")
    )
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
            stance3_na = ifelse(is.na(stance3), 0, stance3),
        )

    # adf <- adf.raw %>% filter(!(coder_id %in% failed_coders))
    adf <- adf.raw
    adf.icr <- adf %>%
        group_by(id) %>%
        mutate(rn = row_number()) %>%
        ungroup() %>%
        mutate(stance3_na = sign(stance3_na) * 0.75)
    adf.icr %>%
        test_icr(unit_var = id, coder_var = rn, stance3_na) %>%
        select(!c(Agreement))

    adf_agg <- adf.raw %>%
        group_by(id, origin) %>%
        summarize(
            stance3.anno.mean = mean(stance3, na.rm = T),
            stance3.anno.mean.na.zero = mean(stance3_na),
            prop.na = mean(is.na(stance3)),
            sd_stance = sd(stance3_na),
            count = n()
        ) %>%
        left_join(opeds, by = "id") %>%
        mutate(id = gsub("aa_opeds_sample/", "", id))
    adf_agg
}

prep_gpt <- function(df, adf) {
    df %>%
        left_join(adf, by = "id") %>%
        mutate(
            model.method = case_when(
                model == 'wordfish' ~ 'Wordfish',
                TRUE ~ paste0(method, "-", ifelse(model == "gpt-3.5-turbo", "3.5t", "4t")),
            ),
            # Right now no adjustments made for coder errors
            bad_anno = F,
            stance3.anno.mean.adj = stance3.anno.mean,
            stance3.anno.mean.adj.na.zero = replace_na(stance3.anno.mean.adj, 0),
            resid.z = (stance3.gpt.na.zero - stance3.anno.mean.adj.na.zero)^2,
            resid = (stance3.gpt - stance3.anno.mean.adj)^2,
            err = (stance3.gpt - stance3.anno.mean.adj),
            pool = "No Pooling",
            ln_word_count = log(word_count),
            text_age = 2024 - year,
            year03 = as.numeric(year < 2003),
        )
}

anno_df <- prep_annotator_labels()

df.stc.4t <- read_tsv(here("annotation/data/aa_opeds_100a.stc.4t.tsv")) %>%
    mutate(model = "gpt-4-turbo") %>%
    scale.stc() %>%
    prep_gpt(anno_df)
df.stc.35t <- read_tsv(here("annotation/data/aa_opeds_100a.stc.35t.tsv")) %>%
    mutate(model = "gpt-3.5-turbo") %>%
    scale.stc() %>%
    prep_gpt(anno_df)
df.zs.4t <- read_tsv(here("annotation/data/aa_opeds_100a.zeroshot5.4t.tsv")) %>%
    mutate(model = "gpt-4-turbo") %>%
    scale.zs5() %>%
    prep_gpt(anno_df)
df.zs.35t <- read_tsv(here("annotation/data/aa_opeds_100a.zeroshot5.35t.tsv")) %>%
    mutate(model = "gpt-3.5-turbo") %>%
    scale.zs5() %>%
    prep_gpt(anno_df)

make_pool <- function(df) {
    df %>%
        group_by(id) %>%
        summarize(
            # Fucking weird reason the order matters here???
            prop.na.gpt = mean(is.na(stance3.gpt)),
            stance3.gpt = mean(stance3.gpt, na.rm = T),
            stance3.gpt.na.zero = mean(stance3.gpt.na.zero)
        ) %>%
        mutate(
            model = first(df$model),
            method = first(df$method),
            iter = 0,
        ) %>%
        prep_gpt(anno_df) %>%
        mutate(
            pool = "Pooling"
        )
}

df.stc.4t.avg <- df.stc.4t %>% make_pool()
df.stc.35t.avg <- df.stc.35t %>% make_pool()
df.zs.35t.avg <- df.zs.35t %>% make_pool()
df.zs.4t.avg <- df.zs.4t %>% make_pool()

df.wordfish <- read_tsv(here('aa_opeds_wf.tsv')) %>% mutate(
    iter=0,
    model='wordfish',
    method='wordfish',
    stance3.gpt = theta_norm,
    stance3.gpt.na.zero = theta_norm,
    prop.na.gpt = 0,
) %>% select(!c(stance3.anno.mean)) %>%
 prep_gpt(anno_df)

df.all <- list(df.stc.4t.avg, df.zs.4t.avg, df.stc.35t.avg, df.zs.35t.avg, df.stc.4t, df.zs.4t, df.stc.35t, df.zs.35t) 
modelnames <- c("StC-pool-4t", "Zeroshot-pool-4t", "StC-pool-35t", "Zeroshot-pool-35t", "StC-4t", "ZeroShot-4t", "StC-3.5t", "ZeroShot-3.5t")

df.noavg <- list(df.stc.4t, df.zs.4t, df.stc.35t, df.zs.35t)
modelnames.noavg <- c("StC-4t", "ZeroShot-4t", "StC-3.5t", "ZeroShot-3.5t")
