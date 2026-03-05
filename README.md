# Asynchronous Request Processing Pattern — Code Examples

Companion repository for my article series on the **Asynchronous Request Processing Pattern** in modern backend systems.

Each example is a fully deployable AWS serverless application built with **AWS SAM**, designed to run within the **AWS Free Tier**.


## What this covers

The core pattern: instead of making a client wait for a long-running operation to finish, the API acknowledges the request immediately, processes it in the background, and lets the client poll for the result.

```
Client  →  POST /jobs  →  202 Accepted  (immediate)
                ↓
         Background Worker  →  processes task
                ↓
Client  →  GET /jobs/{id}  →  DONE + result  (when ready)
```

This pattern appears in production systems handling OCR, ML inference, video encoding, bulk data exports, and anything that cannot complete within a single HTTP request-response cycle.

## Examples

| # | Folder | Description |
|---|--------|-------------|
| 1 | [`Example 1/`](./Example%201/) | **Basic implementation** — core pattern end-to-end with API Gateway, Lambda, and DynamoDB |
| … | *more coming* | Real-world challenges: retries, stuck jobs, duplicate execution, observability |

Each example folder contains its own `README.md` with step-by-step setup and deployment instructions.

## License

[MIT](./LICENSE) — free to use, adapt, and build upon.
