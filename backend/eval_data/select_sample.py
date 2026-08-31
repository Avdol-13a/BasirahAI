import csv, random

random.seed(42)
SAMPLE_SIZE = 200

with open('train.csv') as f:
    rows = list(csv.DictReader(f))

by_grade = {}
for r in rows:
    by_grade.setdefault(r['diagnosis'], []).append(r['id_code'])

total = len(rows)
sample = []
for grade, ids in sorted(by_grade.items()):
    n = round(SAMPLE_SIZE * len(ids) / total)
    random.shuffle(ids)
    picked = ids[:n]
    sample.extend((id_code, grade) for id_code in picked)

random.shuffle(sample)
print(f"Selected {len(sample)} images (stratified, proportional to real class distribution)")
from collections import Counter
print("Sample grade distribution:", dict(sorted(Counter(g for _, g in sample).items())))

with open('sample_manifest.csv', 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['id_code', 'diagnosis'])
    w.writerows(sample)
