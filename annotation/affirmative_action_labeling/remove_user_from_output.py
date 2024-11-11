# Script to remove user from the potato annotation 
# output data

import json
import os
import shutil

USERS = [
        '63656154a6e1fa594f999f7c',
        '5fc2a0d812bc59000b746ee5',
        '633af05da0499598ca6a9834',
        '656c93ddc053d63a280ae0dd',
        '650beb3afdc0195ec4ffda89',
        'test'
]
TASK_ASSIGNMENT = 'annotation_output/task_assignment.json'
TASK_ASSIGNMENT_BAK = 'annotation_output/task_assignment.json.bak'

# Step 1: remove the directory with their label data
# Step 2: reconfigure task_assignment.json
# 2aa: Make a backup copy of task_assignment.json
# 2a: Remove all mention of the user from the "assigned" labels, while keeping track of what they were assigned to
# 2b: Add the items they were assigned to back to the unassigned bucket which uses a counter
#"unassigned": {"aa_opeds_sample/txt/422316037.xml.txt": 1    , "aa_opeds_sample/txt/430675992.xml.txt": 1, "aa_opeds_sample/txt/1370789528.xml.txt": 1},

shutil.copy(TASK_ASSIGNMENT, TASK_ASSIGNMENT_BAK)
tasks = json.load(open(TASK_ASSIGNMENT, 'rt'))

n_users = 0
n_tasks = 0
for user in USERS:
    if os.path.exists(f"annotation_output/{user}"):
        shutil.copytree(f"annotation_output/{user}", f"annotation_output/{user}.deleted")
        shutil.rmtree(f"annotation_output/{user}")
    assigned = tasks['assigned']
    unassigned = tasks['unassigned']
    user_tasks = []
    for key, value in assigned.items():
        # Each key is the question ID
        # and the value is the list of assigned user IDs

        if not isinstance(value, list):
            continue
        if user in value:
            user_tasks.append(key)
            tasks['assigned'][key].remove(user)

    if len(user_tasks):
        n_users += 1

    for qid in user_tasks:
        if 'test' in qid:
            continue
        n_tasks += 1
        if qid in unassigned:
            tasks['unassigned'][qid] += 1
        else:
            tasks['unassigned'][qid] = 1

json.dump(tasks, open(TASK_ASSIGNMENT, 'wt'))
    
print(f"{n_tasks} tasks freed up from {n_users} users")






