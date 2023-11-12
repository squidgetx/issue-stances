import argparse
from squidtools import gpt_utils, robust_task, workflow
import csv

def parse_stance(message, cost, pkey):
    stance = None
    stance_coded = None
    if "strongly against" in message:
        stance_coded = 0
        stance = 'strongly_against'
    elif "somewhat against" in message:
        stance_coded = 1
        stance = 'somewhat_against'
    elif "does not discuss" in message:
        stance_coded = -1
        stance = 'does_not_discuss'
    elif "neutral" in message:
        stance_coded = 2
        stance = 'neutral'
    elif "somewhat in favor" in message:
        stance_coded = 3
        stance = 'somewhat_in_favor'
    elif "strongly in favor" in message:
        stance_coded = 4
        stance = 'strongly_in_favor'
    else:
        print(f"Failed to parse: {message}")

    error = None if stance is not None else "Could not decode stance"

    return {
        'filename': pkey,
        'stance': stance,
        'stance_coded': stance_coded,
        'raw_response': message,
        'cost': cost,
        'error': error
    }

def parse_stances(stances):
    return [parse_stance(l['raw_response'], l['cost'], l['_pkey']) for l in stances]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Use ChatGPT to stance news articles. Outputs TSV to standard out, but progress is also saved in json by default"
    )
    
    parser.add_argument(
        "tsv",
        type=str,
        help="Path to the tsv created by get-stance"
    )

    args = parser.parse_args()
    reader = csv.DictReader(open(args.tsv, 'rt'), delimiter='\t')
    stances = [r for r in reader]
    results = parse_stances(stances)
    outname= workflow.next_step_filename(args.tsv, 'parsed')
    writer = csv.DictWriter(open(outname, 'wt'), delimiter='\t', fieldnames=results[0].keys())
    writer.writeheader()
    writer.writerows(results)

    num_nones = sum([1 if row['stance'] is None else 0 for row in results])
    print('number of nones is ' + str(num_nones))


