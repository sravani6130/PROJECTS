import re
from datetime import datetime
import sys

log_file = 'all_metrics_utf8.log'

tasks = {}

def parse_prefix_time(ts_str):
    # Example: 2026/05/04 23:55:27
    return datetime.strptime(ts_str, '%Y/%m/%d %H:%M:%S')

try:
    with open(log_file, 'r', encoding='utf-8') as f:
        for line in f:
            if '[METRIC]' not in line:
                continue
            
            # Extract log timestamp
            # 2026/05/04 23:55:27 [METRIC] ...
            ts_match = re.match(r'^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})', line)
            if not ts_match: continue
            log_ts = parse_prefix_time(ts_match.group(1))
            
            metric_part = line.split('[METRIC]')[1].strip()
            action, data_str = metric_part.split(': ', 1)
            
            data = {}
            for item in data_str.split(','):
                if '=' in item:
                    k, v = item.split('=', 1)
                    data[k.strip()] = v.strip().strip('"')
            
            task_id = data.get('task_id')
            if not task_id: continue
            
            if task_id not in tasks:
                tasks[task_id] = {'receive_producer': None, 'send_producer': None, 'receive_consumer': [], 'complete_consumer': [], 'type': 'N/A'}
            
            if action == 'PRODUCER_RECEIVE':
                tasks[task_id]['receive_producer'] = log_ts
                tasks[task_id]['type'] = data.get('type', 'N/A')
            elif action == 'PRODUCER_SEND':
                tasks[task_id]['send_producer'] = log_ts
            elif action == 'CONSUMER_RECEIVE':
                tasks[task_id]['receive_consumer'].append(log_ts)
            elif action == 'CONSUMER_COMPLETE':
                tasks[task_id]['complete_consumer'].append(log_ts)
except Exception as e:
    print(f"Error reading logs: {e}")
    sys.exit(1)

# Calculate Metrics
latencies = [] 
processing_times = [] 
e2e_latencies = [] 

for tid, t in tasks.items():
    if t['receive_producer'] and t['receive_consumer']:
        for rc in t['receive_consumer']:
            latencies.append((rc - t['receive_producer']).total_seconds() * 1000)
    
    if t['receive_consumer'] and t['complete_consumer']:
        for rc, cc in zip(t['receive_consumer'], t['complete_consumer']):
            proc = (cc - rc).total_seconds()
            processing_times.append(proc)
            if t['receive_producer']:
                e2e = (cc - t['receive_producer']).total_seconds()
                e2e_latencies.append(e2e)

if not latencies:
    # If no latency found, maybe all are within the same second.
    # Let's just assume 0 for those if they exist.
    if any(t['receive_producer'] and t['receive_consumer'] for t in tasks.values()):
         avg_latency = 0
         p95_latency = 0
    else:
        print(f"No metrics found. Parsed {len(tasks)} tasks.")
        sys.exit(0)
else:
    avg_latency = sum(latencies) / len(latencies)
    p95_latency = sorted(latencies)[int(len(latencies) * 0.95)]

throughput = len(e2e_latencies) / 10.0 

print(f"# Performance Metrics Report")
print(f"\n## Summary")
print(f"- **Total Tasks Submitted**: {len(tasks)}")
print(f"- **Total Tasks Completed**: {len(e2e_latencies)}")
print(f"- **Average Network Latency (Producer -> Consumer)**: {avg_latency:.2f} ms")
print(f"- **P95 Network Latency**: {p95_latency:.2f} ms")
print(f"- **System Throughput**: {throughput:.2f} tasks/sec")

print(f"\n## Detailed Task Stats (Sample)")
print(f"| Task ID | Type | Net Latency | Proc Time | E2E Latency |")
print(f"| --- | --- | --- | --- | --- |")

sorted_tasks = sorted(tasks.items(), key=lambda x: x[1]['receive_producer'] if x[1]['receive_producer'] else datetime.min)

for tid, t in sorted_tasks:
    if not t['receive_consumer']: continue
    
    p_lat = f"{(t['receive_consumer'][0] - t['receive_producer']).total_seconds() * 1000:.2f}ms" if t['receive_producer'] else "N/A"
    proc_t = f"{(t['complete_consumer'][0] - t['receive_consumer'][0]).total_seconds():.2f}s" if t['complete_consumer'] else "N/A"
    e2e = f"{(t['complete_consumer'][0] - t['receive_producer']).total_seconds():.2f}s" if t['complete_consumer'] and t['receive_producer'] else "N/A"
    
    print(f"| {tid} | {t['type']} | {p_lat} | {proc_t} | {e2e} |")
