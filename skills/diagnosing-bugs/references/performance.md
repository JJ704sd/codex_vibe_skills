# Performance Measurement

## Build a comparable benchmark

- Exercise the same caller-visible operation and representative data before and after.
- Pin code revision, runtime, dependencies, configuration, hardware class, dataset, concurrency, warmup, and cache state.
- Separate setup from the measured interval unless startup is the target.
- Use enough repetitions to report median and a tail percentile or range; preserve raw samples when practical.
- Randomize or alternate before/after ordering when environmental drift could bias results.

## Match evidence to the limit

| Suspected limit | Useful evidence |
| --- | --- |
| CPU | Sampling profile, hot-path counts, runtime profile |
| Memory/GC | Allocations, retained objects, peak/RSS, pause distribution |
| Database | Query plan, rows examined, round trips, lock waits |
| Network/I/O | Trace or waterfall, payload size, read/write counts, queue time |
| Concurrency | Throughput curve, saturation, queue depth, contention, tail latency |
| Frontend/bundle | Bundle composition, parse/execute time, rendering profile |
| Cost | Work units per successful operation at representative load |

Compare distributions and absolute impact, not percentages alone. State noise, sample count, secondary metrics, untested workloads, and limits on generalizing the result.
