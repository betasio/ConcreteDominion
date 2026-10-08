"""Local-only HTTP smoke/load probe: python3 -m server.load_probe --url http://127.0.0.1:8765"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import time
from urllib.request import urlopen
from urllib.error import HTTPError
from urllib.parse import urlsplit

def probe(url, workers, count):
    target=url.rstrip("/")+"/v1/me"
    if urlsplit(target).hostname not in ("127.0.0.1","localhost","::1"):
        raise ValueError("Load probe restricted to localhost; no production stress tests")
    def request(_):
        begin=time.monotonic()
        try:
            with urlopen(target,timeout=5) as response:
                status=response.status
        except HTTPError as exc:
            status=exc.code
        except Exception:
            status=0
        return status,(time.monotonic()-begin)*1000
    start=time.monotonic()
    with ThreadPoolExecutor(max_workers=workers) as pool:
        results=list(pool.map(request,range(count)))
    durations=sorted(ms for _,ms in results)
    statuses={}
    for code,_ in results:
        statuses[code]=statuses.get(code,0)+1
    report={"requests":count,"workers":workers,"statuses":statuses,
            "elapsed_seconds":round(time.monotonic()-start,3),
            "median_ms":round(durations[len(durations)//2],2),
            "p95_ms":round(durations[min(len(durations)-1,int(len(durations)*.95))],2)}
    print(json.dumps(report,indent=2))
    return report

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url",default="http://127.0.0.1:8765")
    parser.add_argument("--workers",type=int,default=4)
    parser.add_argument("--requests",type=int,default=40)
    args=parser.parse_args()
    if not 1<=args.workers<=16 or not 1<=args.requests<=500:
        parser.error("Use 1-16 workers and 1-500 requests")
    probe(args.url,args.workers,args.requests)

if __name__=="__main__":
    main()
