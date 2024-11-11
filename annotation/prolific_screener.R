library(tidyverse)
library(here)
n_questions <- 6
df <- read_tsv(here('annotation/data/prolific_screener_responses.tsv')) %>% mutate(
    know1 = QID1 == 1,
    know2 = QID2 == 1,
    know3 = QID3 == 2,
    know5 = QID5 == 3,
    read1 = QID6 == 1,
    read2 = QID8 == 5,
    pk_score = know1 + know2 + know3 + know5,
    read_score = read1 + read2,
    total = pk_score + read_score,
)

passes <- df %>% 
    filter(pk_score >= 3) %>% 
    filter(read_score == 2) %>% 
    select(PROLIFIC_PID) 
outpath <- here('annotation/data/prolific_screener_passes.tsv')
passes %>%
    write_tsv(outpath)
print(paste(nrow(passes), "out of", nrow(df), "passed prescreen, IDs written to ", outpath))
