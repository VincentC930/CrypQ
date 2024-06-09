import psycopg2
import os
from dotenv import load_dotenv
from datetime import datetime, timedelta
import time

load_dotenv()

conn = psycopg2.connect("dbname=%s user=%s password=%s host=%s port=%s" % (os.getenv("DBNAME"), os.getenv("DBUSER"), os.getenv("PASSWORD"), os.getenv("HOST"), os.getenv("PORT")))

cur = conn.cursor()

first_update_block = 19006000 # If S_0 is being used

get_timestamps = f"SELECT TIMESTAMP FROM BLOCKS WHERE NUMBER >= {first_update_block} ORDER BY TIMESTAMP"
cur.execute(get_timestamps)
timestamps = [timestamp[0] for timestamp in cur.fetchall()]

wait_times = [int((t2 - t1).total_seconds()) for t1, t2 in zip(timestamps, timestamps[1:])]

prev_run_time = datetime.now()
curr_update_block = first_update_block

for wait_time in wait_times:
    if curr_update_block == first_update_block:
        pass
    else:
        curr_time = datetime.now()
        time_delta = timedelta(seconds=wait_time)
        if curr_time - prev_run_time < time_delta:
            time.sleep((prev_run_time + time_delta - curr_time).total_seconds())
        else:
            print(f"Update on block {curr_update_block} executed {str((curr_time - prev_run_time + time_delta).total_seconds())}s late")

    update = f'''
    insert update workload here
    '''
    print(f'---Update for block {curr_update_block}---')
    cur.execute(update)
    print(cur.statusmessage)
    curr_update_block += 1

print('---Complete---')