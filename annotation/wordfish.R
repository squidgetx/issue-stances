library(quanteda)
library(quanteda.textmodels)
library(readtext)
source(here("annotation/clean-labels.R"))
# Get the filenames from anno_df

adf_corpus <- corpus(readtext(
    Sys.glob("opeds_aa/txt/*.txt"),
    docvarsfrom = "filenames"
))
docvars(adf_corpus)$id <- paste0("txt/", docvars(adf_corpus)$docvar1, ".txt")
docvars(adf_corpus)$labeled <- docvars(adf_corpus)$id %in% anno_df$id
docvars(adf_corpus)
adf_dfm <- adf_corpus %>%
    corpus_subset(labeled) %>%
    tokens(remove_punct = T, remove_numbers = T, remove_url = T) %>%
    tokens_tolower() %>%
    tokens_remove(stopwords("en")) %>%
    tokens_select(min_nchar = 2) %>%
    dfm() %>%
    dfm_trim(min_docfreq = 2)
dim(adf_dfm)
adf_dfm

# Select the poles for wordfish
extremes <- anno_df %>%
    filter(!is.na(stance3.anno.mean)) %>%
    filter(abs(stance3.anno.mean) > 0.75)
# SD zero and max count which should should be the "strongest" stance articles
extremes %>%
    filter(stance3.anno.mean == -1 & sd_stance == 0) %>%
    arrange(desc(count)) %>%
    select(id)
# Manually inspect
# txt/1034256694.xml.txt - pretty good example
# txt/2765919087.xml.txt - better
extremes %>%
    filter(stance3.anno.mean == 1 & sd_stance == 0) %>%
    arrange(desc(count)) %>%
    select(id)
# txt/2452692303.xml.txt good
poles <- c("txt/2765919087.xml.txt", "txt/2452692303.xml.txt")
indexes <- match(poles, docvars(adf_dfm)$id)


adf_wf <- textmodel_wordfish(adf_dfm, dir = indexes)

wf_results <- list(theta = adf_wf$theta) %>%
    cbind(adf_dfm %>% docvars() %>% select(id)) %>%
    arrange(theta) %>%
    select(id, theta) %>% 
    left_join(anno_df %>% select(id, stance3.anno.mean)) %>% 
    mutate(theta_norm = theta * 0.5) %>% 
    distinct(id, .keep_all=T)
wf_results
wf_results %>%
    write_tsv(here('aa_opeds_wf.tsv'))
wf_results %>% ggplot(aes(x = theta, y = stance3.anno.mean)) +
    geom_point()

wf_results$theta %>% quantile

test_mse <- function(c) {
    theta_norm <- wf_results$theta * c
    mse <- mean((wf_results$stance3.anno.mean - theta_norm)^2, na.rm=T)
    mse
}
baseline <- mean((wf_results$stance3.anno.mean)^2, na.rm=T)
cs <- seq(0.1, 1, 0.01)
mse_cvs <- sapply(seq(0.1, 1, 0.01), test_mse)
mse_df <- data.frame(c=cs, mse=mse_cvs)
mse_df %>% ggplot(aes(x=c, y=mse)) + geom_point()

# Wordfish is.. completely useless?
# Cannot improve on the baseline model
# "Normal" normalization value of 0.5 is bad
# Collapsing the normalization to 0 approaches the baseline model performance, lol



# Tweets

source(here("SemEval2016/clean-labels.R"))
tdf_corpus <- corpus(df.stc.4t)
tdf_dfm <- tdf_corpus %>%
    tokens(remove_punct = T, remove_numbers = T, remove_url = T) %>%
    tokens_tolower() %>%
    tokens_remove(stopwords("en")) %>%
    tokens_select(min_nchar = 2) %>%
    dfm() %>%
    dfm_trim(min_docfreq = 2)

# Select the poles for wordfish
extremes <- anno %>%
    filter(!is.na(stance3.anno.mean)) %>%
    filter(abs(stance3.anno.mean) > 0.75)
# SD zero and max count which should should be the "strongest" stance articles
extremes %>%
    filter(stance3.anno.mean == -1 & sd_stance == 0) %>%
    arrange(desc(n)) %>% select(id, text)
# Manually inspect
# 2312
extremes %>%
    filter(stance3.anno.mean == 1 & sd_stance == 0) %>%
    arrange(desc(n)) %>%
    select(id, text)
# 91
poles <- c(2312, 91)
indexes <- match(poles, docvars(tdf_dfm)$id)

tweets_wf <- textmodel_wordfish(tdf_dfm, dir = indexes)
norm_fct <- sd(anno$stance3.anno.mean, na.rm=T) / sd(tweets_wf$theta)
norm_fct

wf_results <- list(theta = tweets_wf$theta) %>%
    cbind(tdf_dfm %>% docvars() %>% select(id)) %>%
    arrange(theta) %>%
    select(id, theta) %>% 
    left_join(anno %>% select(id, stance3.anno.mean)) %>% 
    mutate(theta_norm = theta * norm_fct) %>% 
    distinct(id, .keep_all=T)
wf_results$theta %>% hist
wf_results %>% ggplot(aes(x=stance3.anno.mean, y=theta)) + geom_point()
cor(wf_results$theta, wf_results$stance3.anno.mean, use='complete.obs')
wf_results %>%
    write_tsv(here('tweets_wf.tsv'))
