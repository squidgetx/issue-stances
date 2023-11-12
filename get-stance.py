import os
import argparse
import csv
import json
from squidtools import gpt_utils, robust_task

AFFIRMATIVE_ACTION = 'affirmative action'
IMMIGRATION = 'immigration'
ESSAY = 'essay'

def get_prompt(issue, essay=ESSAY):
    return f"""
Another assistant has summarized an {essay} and noted its perspective on {issue}. 

How does the {essay} argue for or against {issue}? Is it strongly in favor, somewhat in favor, neutral, somewhat against, or strongly against {issue}?
"""

   
def label_record(summary, issue):
    prompt = get_prompt(issue)
    message, cost = gpt_utils.system_prompt(
        prompt, 
        summary,
        model='gpt-4'
    )
        
    return {
        'raw_response': message,
        'cost': cost,
    }

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Use ChatGPT to label news articles. Outputs TSV to standard out, but progress is also saved in json by default"
    )
    
    parser.add_argument(
        "tsv",
        type=str,
        help="Path to the tsv created by parse-relevance"
    )
    parser.add_argument(
        "issue",
        type=str,
        choices=[AFFIRMATIVE_ACTION, IMMIGRATION],
        help="Issue to check relevance for",
    )

    args = parser.parse_args()
    issue = args.issue

    def task(msg):
        return label_record(msg, issue)

    with open(args.tsv, 'rt') as f:
        dirname = os.path.dirname(args.tsv)
        if dirname:
            os.chdir(dirname)
        reader = csv.DictReader(f, delimiter='\t')
        records = {f['filename']: f['raw_response'] for f in reader if f['label'] == 'True'}
        results = robust_task.robust_task(records, task, progress_name=f'stance-progress-{issue}.json')
        print(robust_task.naive_dict_to_tsv(results))
