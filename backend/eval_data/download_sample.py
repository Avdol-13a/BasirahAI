import csv, os, time
from kaggle.api.kaggle_api_extended import KaggleApi

api = KaggleApi()
api.authenticate()

os.makedirs('images', exist_ok=True)

with open('sample_manifest.csv') as f:
    rows = list(csv.DictReader(f))

total = len(rows)
for i, row in enumerate(rows, 1):
    id_code = row['id_code']
    dest = f'images/{id_code}.png'
    if os.path.exists(dest):
        continue
    file_name = f'train_images/{id_code}.png'
    for attempt in range(3):
        try:
            api.competition_download_file('aptos2019-blindness-detection', file_name, path='images', quiet=True)
            downloaded = f'images/{id_code}.png'
            if os.path.exists(downloaded):
                break
        except Exception as e:
            print(f"  retry {attempt+1} for {id_code}: {e}")
            time.sleep(2)
    if i % 20 == 0 or i == total:
        print(f"{i}/{total} downloaded")

print("done")
