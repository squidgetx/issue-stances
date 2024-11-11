library(tidyverse)
library(here)

# Code to analyze the quality of the annotator labels
df <- read_tsv(here('annotation/annotator.labels.clean.tsv')) %>% mutate(
    stance.class = ifelse(is.na(stance3), 0, sign(df$stance3))
)

## Relevance label comes from GPT
table(df$relevant, df$stance.class, useNA='ifany')

df.distances <- df %>% group_by(filename, relevant) %>% summarize(
    first_label = first(stance.class),
    second_label = last(stance.class),
    label_distance = abs(first_label - second_label),
    n=n()
)

table(df.distances$n)
table(df.distances$label_distance)
table(df.distances$label_distance) %>% prop.table
table(df.distances %>% filter(relevant) %>% .$label_distance)
table(df.distances %>% filter(relevant) %>% .$label_distance) %>% prop.table

# ok not bad for the general pop actually

df.distances <- df %>% filter(coder_quality) %>% group_by(filename) %>% summarize(
    first_label = first(stance.class),
    second_label = last(stance.class),
    label_distance = abs(first_label - second_label),
    n=n()
)

table(df.distances$n)
table(df.distances %>% filter(n>1) %>% .$label_distance)
# it's all decent