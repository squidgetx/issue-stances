import argparse

from squidtools import gpt_utils, robust_task, workflow
import csv

def parse_discussion(discussion):
    # For now, simple phrase detection
    discusses = [
        "provide",
        "address",
        "mention",
        "discuss",
        "state"
    ]
    adverbs = [
        "",
        "directly ",
        "explicitly "
    ]
    howevers = [
        "however",
        "while",
        "but",
        "infer"
    ]
    but = False
    for h in howevers:
        if h in discussion.lower():
            but = True

    for adverb in adverbs:
        for discuss in discusses:
            phrase = f"not {adverb}{discuss}"
            if phrase in discussion.lower() and not but:
                return False
    return True


def parse_label(row):
    issue = row['issue']
    message = row.get('message') 
    cost = row.get('cost')
    filename = row.get('filename') or row.get('_pkey')
    paragraphs = [p.strip() for p in message.split('\n') if p.strip()]
    error = None
    relevant = None
    summary = None
    discussion = None
    n_paragraphs = len(paragraphs)

    if len(paragraphs) == 2:
        summary = paragraphs[0]
        discussion = paragraphs[1]
        relevant = parse_discussion(discussion)
    else:
        print(paragraphs)
        error = "Could not parse response."
        
    return {
        'filename': filename,
        'summary': summary,
        'discussion': discussion,
        'label': relevant,
        'raw_response': message,
        'cost': cost,
        'error': error,
        'n_paragraphs': n_paragraphs,
    }

def parse_labels(labels):
    return [parse_label(l) for l in labels]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Parse responses for relevance"
    )
    
    parser.add_argument(
        "tsv",
        type=str,
        help="Path to the tsv created by label-topic"
    )


    args = parser.parse_args()
    reader = csv.DictReader(open(args.tsv, 'rt'), delimiter='\t')
    labels = [r for r in reader]
    results = parse_labels(labels)
    outname = workflow.next_step_filename(args.tsv, 'parsed')
    writer = csv.DictWriter(open(outname, 'wt'), delimiter='\t', fieldnames=results[0].keys())
    writer.writeheader()
    writer.writerows(results)

    n_relevant = sum([1 if r['label'] else 0 for r in results])
    print(f"{n_relevant}/{len(results)} ({int(n_relevant/len(results) * 100)}%) labeled TRUE")


    errors = [{'filename': r['filename'], 'message': r['raw_response']} for r in results if r['error']]
    errname = workflow.next_step_filename(args.tsv, 'errors')
    writer = csv.DictWriter(open(errname, 'wt'), delimiter='\t', fieldnames=['filename', 'message'])
    writer.writeheader()
    writer.writerows(errors)
    print(f"{len(errors)} errors written to {errname}.")

    
