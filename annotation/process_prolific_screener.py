from squidtools import qualtrics, util

import json
responses = json.load(open('data/qualtrics/SV_6L3BjfgteqXMA7A/Prolific Screener.json', 'rt'))
records = qualtrics.get_records(responses) 
util.write_csv(records, 'data/prolific_screener_responses.tsv', delimiter='\t')
