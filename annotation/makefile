default:
	potato start affirmative_action_labeling -p 9001

fetch:
	scp -r twee-server:~/issue-stances/annotation/affirmative_action_labeling/annotation_output .

prescreen:
	node fetch_qualtrics.mjs
	python process_prolific_screener.py
	Rscript prolific_screener.R

annotator.labels.clean.tsv:
	Rscript clean-labels-2.R

nafta:
	python make_potato_datafile.py
	rm -rf nafta_potato/annotation_output 
	potato start nafta_potato -p 9001