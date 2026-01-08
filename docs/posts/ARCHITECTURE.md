# Architecture

## Overview

This project deploys a production-ready AWS Bedrock Knowledge Base backed by S3 Vectors for cost-effective document embedding and retrieval.

## Components

```
┌──────────────┐
│   Lambda     │  Fetches URLs, cleans HTML, stores in S3
│ fetch_docs   │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│  S3: api-docs        │  Source documents (plain text)
└──────┬───────────────┘
       │
       │ (Bedrock reads)
       ▼
┌──────────────────────┐
│ Bedrock KB           │  Orchestrates embedding process
│ + Data Source        │
└──────┬───────────────┘
       │
       │ (Titan Embeddings)
       ▼
┌──────────────────────┐
│ S3 Vectors           │  Vector storage (256-dim)
│ + Index              │
└──────────────────────┘
       │
       ▼
    RAG Queries
```

## Infrastructure

### Storage
- **S3 Bucket (api-docs)**: Stores cleaned documentation as plain text
- **S3 Vectors Bucket**: Stores 256-dimensional embeddings
- **S3 Vectors Index**: Enables similarity search (Euclidean distance)

### Compute
- **Lambda (fetch_docs)**: Fetches URLs, processes HTML, splits large files
  - Runtime: Python 3.12
  - Architecture: ARM64 (Graviton)
  - Timeout: 120s
  - Memory: 512MB

### AI/ML
- **Bedrock Knowledge Base**: Manages RAG workflow
  - Embedding Model: amazon.titan-embed-text-v2:0
  - Chunking: Fixed size (300 tokens, 20% overlap)
- **Data Source**: Connects S3 bucket to Knowledge Base

### IAM
- **KB Role**: Allows Bedrock to read S3, write vectors, invoke models
- **Lambda Role**: Allows Lambda to write to S3

## Data Flow

1. **Ingestion**
   ```
   URL → Lambda → Clean HTML → Split if >400KB → S3 (api-docs)
   ```

2. **Embedding**
   ```
   S3 (api-docs) → KB Sync → Titan Embeddings → S3 Vectors
   ```

3. **Retrieval**
   ```
   Query → KB Retrieve → S3 Vectors → Return relevant chunks
   ```

## Key Design Decisions

### 1. S3 Vectors vs OpenSearch
- **Cost**: ~$2-5/month vs $35-40/month (90% savings)
- **Scalability**: Pay-per-GB vs minimum OCU
- **Tradeoff**: Newer feature, less documentation

### 2. File Splitting (400KB limit)
- **Problem**: Large files cause metadata overflow (2KB limit)
- **Solution**: Split at 400KB, preserve headers for context
- **Benefit**: Reliable Bedrock sync, no metadata errors

### 3. Plain Text Processing
- **Problem**: HTML/JSON fragments in embeddings
- **Solution**: Extract clean text, remove code blocks
- **Benefit**: Meaningful embeddings, better retrieval

### 4. Non-Filterable Metadata
```terraform
nonFilterableMetadataKeys = [
  "x-amz-bedrock-kb-source-uri",
  "x-amz-bedrock-kb-chunk-id",
  "S3VECTORS-EMBED-SRC-CONTENT"
]
```
- **Purpose**: Prevent metadata from exceeding 2KB filterable limit
- **Impact**: Enables large source files, stable sync

## File Organization

```
domain/path/section/filename
└─ docs_stripe_com/
   └─ api/
      └─ authentication/
         ├─ authentication_abc123_20260107.txt
         └─ errors/
            ├─ part1of3_def456_20260107.txt
            ├─ part2of3_def456_20260107.txt
            └─ part3of3_def456_20260107.txt
```

## Security

- **S3**: Server-side encryption (AES256), public access blocked
- **IAM**: Least privilege policies, source account/ARN conditions
- **Lambda**: No secrets in code, environment variables for config
- **KB Role**: Scoped to specific resources, no wildcard permissions

## Scalability

- **Lambda**: Auto-scales with concurrent executions
- **S3**: Unlimited storage, auto-scaling
- **S3 Vectors**: Supports up to 2 billion vectors per index
- **Bedrock KB**: Managed service, auto-scaling

## Cost Optimization

- ARM64 Lambda (20% cheaper than x86)
- 7-day CloudWatch log retention
- Intelligent-Tiering for S3 storage
- No reserved capacity charges
- Pay-per-use pricing model

## Monitoring

- CloudWatch Logs: Lambda execution, errors
- Bedrock KB: Ingestion job status, statistics
- S3 metrics: Storage, requests

## Limits

- **Lambda timeout**: 120 seconds (configurable)
- **File size**: 400KB per part (configurable)
- **S3 Vectors**: 2KB filterable metadata per vector
- **Titan embeddings**: 8K tokens max per chunk
