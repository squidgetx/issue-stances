import os
import csv
import argparse
import json
from squidtools import gpt_utils, robust_task

ESSAY = 'essay'
AFFIRMATIVE_ACTION = 'affirmative action'
IMMIGRATION = 'immigration'
ISSUE = IMMIGRATION


def get_prompt(issue, essay=ESSAY):
    return f"""
First, summarize the {essay} provided by the user. 
Then, provide a second paragraph discussing the {essay}'s perspective on {issue}. 
"""
#If the essay did not discuss {issue}, just say "{issue} is not discussed in the {essay}."


def label_lines(lines, issue):
    prompt = get_prompt(issue)
    message, cost = gpt_utils.system_prompt(prompt, "\n".join(lines))
    return {
        'message': message,
        'cost': cost
    }
    

def make_paragraphs(f):
    text = "\n".join([lines.strip() for lines in f])
    return text.split("\n\n")


def label_file(filename, issue):
    with open(filename, "rt") as f:
        lines = make_paragraphs(f)
        result = label_lines(lines[0:10], issue)
        result['filename'] = filename
        result['issue'] = issue
        return result


def get_files_in_dir(dirname):
    for filename in os.listdir(dirname):
        if filename.endswith(".txt"):
            yield os.path.join(dirname, filename)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="""Use ChatGPT to label text for relevance to a given issue. 
        Outputs TSV to standard out, but progress is also saved in json by default"""
    )
    parser.add_argument(
        "path",
        type=str,
        help="Path to the txt file(s). If directory, extracts for every .txt file in the directory. If tsv, extracts for filenames marked under the tsv.",
    )
    parser.add_argument(
        "issue",
        type=str,
        choices=[AFFIRMATIVE_ACTION, IMMIGRATION],
        help="Issue to check relevance for",
    )
    parser.add_argument(
        "--overwrite",
        dest='overwrite',
        action='store_const',
        const=True,
        required=False,
        default=False,
        help="Pass this flag to re-get relevance"
    )
    parser.add_argument(
        "--format",
        dest='format',
        type=str,
        required=False,
        default='tsv',
        choices=['tsv', 'json'],
        help="Output as tsv or json. Default is TSV")

    args = parser.parse_args()
    skip_existing = not args.overwrite
    issue = args.issue
    progress_file = f'labeling-progress-{issue}.json'
    files = None

    def label_task(filename):
        return label_file(filename, issue)

    if os.path.isdir(args.path):
        os.chdir(args.path)
        files = list(get_files_in_dir('txt/'))

    elif args.path.endswith('.tsv'):
        with open(args.path, 'rt') as f:
            reader = csv.DictReader(f, delimiter='\t')
            files = [row['filename'] for row in reader]
            dirname = os.path.dirname(args.path)
            if dirname:
                os.chdir(dirname)
    else:
        files = [args.path]
    results = robust_task.robust_task(
            files, 
            label_task, 
            progress_name=progress_file,
            skip_existing=skip_existing
        )
    if args.format == 'tsv':
        print(robust_task.naive_dict_to_tsv(results))
    else:
        json.dumps(results, indent=4)