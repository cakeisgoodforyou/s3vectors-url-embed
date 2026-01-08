---
layout: default
title: Architecture - S3 Vectors URL Embed
---

# Architecture: S3 Vectors URL Embed

[← Back to Project](s3-vectors-url-embed)

---

## System Overview

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
       ▼
┌──────────────────────┐
│ Bedrock KB           │  Orchestrates embedding
│ + Data Source        │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ S3 Vectors + Index   │  Vector storage (256-dim)
└──────────────────────┘
       │
       ▼
    RAG Queries
```

---

## Components

### Lambda Function: fetch_docs
**Purpose**: Fetch and process URLs into clean text

**Specifications**:
- Runtime: Python 3.12
- Architecture: ARM64 (Graviton)
- Timeout: 120 seconds
- Memory: 512MB

**Process**:
1. Receives URLs via event payload
2. Fetches HTML content
3. Extracts main content (removes nav, scripts, styles)
4. Fixes encoding issues (mojibake)
5. Splits if >400KB with header preservation
6. Stores in S3 as plain text

### S3 Bucket: api-docs
**Purpose**: Store processed documentation

**Configuration**:
- Encryption: AES256
- Public access: Blocked
- Versioning: Disabled (not needed)
- Lifecycle: None (documents retained)

### Bedrock Knowledge Base
**Purpose**: Orchestrate RAG workflow

**Configuration**:
- Embedding Model: amazon.titan-embed-text-v2:0
- Dimensions: 256
- Chunking: Fixed size (300 tokens, 20% overlap)

### Data Source
**Purpose**: Connect S3 bucket to Knowledge Base

**Configuration**:
- Type: S3
- Source: api-docs bucket
- Parsing: Bedrock Foundation Model

### S3 Vectors
**Purpose**: Store and query vector embeddings

**Configuration**:
- Data type: float32
- Dimension: 256
- Distance metric: Euclidean
- Non-filterable metadata keys: source-uri, chunk-id, content

### IAM Roles & Policies
**KB Role**: Read S3 (api-docs), write S3 Vectors, invoke Bedrock models  
**Lambda Role**: Write S3 (api-docs)

---

## Data Flow

### 1. Ingestion Flow
```
User provides URL
    ↓
Lambda invoked
    ↓
Fetch HTML content
    ↓
Clean & extract text
    ↓
Split if >400KB (preserve headers)
    ↓
Store in S3 (api-docs bucket)
    ↓
Manual trigger: start-ingestion-job
    ↓
Bedrock reads from S3
    ↓
Create embeddings with Titan
    ↓
Store vectors in S3 Vectors
```

### 2. Query Flow
```
User query
    ↓
Bedrock KB retrieve API
    ↓
Query S3 Vectors index
    ↓
Return top-k chunks
    ↓
(Optional) RetrieveAndGenerate
    ↓
Claude generates answer
```

---

## Key Design Decisions

### Why S3 Vectors?
**Cost**: $0.023/GB vs OpenSearch minimum $35/month  
**Scalability**: Auto-scaling, pay-per-GB  
**Simplicity**: No cluster management

**Tradeoff**: Newer feature (Dec 2024), less documentation

### Why Split at 400KB?
**Problem**: Files >500KB cause Bedrock sync failures due to 2KB metadata limit

**Solution**: Pre-split to 400KB ensures:
- Each file has manageable metadata
- Bedrock chunks don't inherit excessive metadata
- Sync completes reliably

**Context Preservation**: Headers included in each part so embeddings understand context

### Why Plain Text?
**Problem**: HTML/JSON fragments in embeddings produce unusable results

**Solution**: 
- Extract main content only
- Remove navigation, scripts, styles
- Fix encoding (ftfy library)
- Normalize Unicode
- Result: Clean, readable text

### Why Non-Filterable Metadata?
**Problem**: S3 Vectors has 2KB filterable metadata limit

**Solution**: Mark large fields as non-filterable:
- `x-amz-bedrock-kb-source-uri` (long S3 paths)
- `x-amz-bedrock-kb-chunk-id` (UUIDs)
- `S3VECTORS-EMBED-SRC-CONTENT` (content previews)

**Impact**: Enables reliable sync without metadata overflow

---

## File Organization

```
s3://bucket/
└── docs_stripe_com/
    └── api/
        ├── authentication/
        │   └── authentication_abc123_20260107.txt
        └── errors/
            ├── part1of3_def456_20260107.txt
            ├── part2of3_def456_20260107.txt
            └── part3of3_def456_20260107.txt
```

**Naming Convention**:
- Domain: `docs_stripe_com`
- Path: `api/authentication`
- Section: `authentication` or `errors`
- Hash: `abc123` (MD5 of URL)
- Date: `20260107` (YYYYMMDD)
- Part: `part1of3` (if split)

---

## Security Model

### Encryption
- S3: Server-side encryption (AES256)
- In-transit: TLS 1.2+

### IAM Policies
- **Least Privilege**: Each role has minimal required permissions
- **Resource Scoping**: Policies reference specific buckets/models
- **Trust Policies**: Restrict by account ID and source ARN

### Network
- S3: Private (VPC endpoints possible)
- Lambda: No VPC needed (uses public endpoints)
- Bedrock: AWS managed, private

### Secrets
- No hardcoded credentials
- Environment variables for configuration
- IAM roles for authentication

---

## Scalability

| Component | Limit | Scaling |
|-----------|-------|---------|
| Lambda | 1000 concurrent executions | Auto |
| S3 | Unlimited | Auto |
| S3 Vectors | 2 billion vectors/index | Manual (new index) |
| Bedrock KB | Managed | Auto |

**Bottleneck**: Lambda concurrency (1000 default)  
**Solution**: Request increase or batch URLs

---

## Monitoring

### CloudWatch Logs
- Lambda execution logs (7-day retention)
- Error tracking
- Performance metrics

### Bedrock KB Metrics
- Ingestion job status
- Document counts (scanned, indexed, failed)
- Sync duration

### S3 Metrics
- Storage size
- Request counts
- Error rates

---

## Cost Breakdown

### Development Environment
| Service | Usage | Cost/Month |
|---------|-------|------------|
| Lambda | 100 invocations | $0.02 |
| Lambda Duration | 1000 GB-seconds | $0.17 |
| S3 (docs) | 1GB | $0.023 |
| S3 Vectors | 2GB | $0.046 |
| Titan Embeddings | 1M tokens | $0.20 |
| **Total** | | **$0.46** |

### Production Scale (100GB docs)
| Service | Cost/Month |
|---------|------------|
| S3 Vectors | $2.30 |
| Lambda | $2.00 |
| Embeddings | $20.00 |
| **Total** | **$24.30** |

vs OpenSearch: **$35-40 minimum**

---

## Trade-offs

### S3 Vectors
**Pros**: Massive cost savings, auto-scaling  
**Cons**: New feature, limited documentation

### Pre-splitting Files
**Pros**: Reliable sync, predictable metadata  
**Cons**: More files to manage, complexity

### Plain Text Only
**Pros**: Clean embeddings, better retrieval  
**Cons**: Loses some formatting context

---

## Future Considerations

- **Multi-region**: Deploy to multiple regions for lower latency
- **Incremental sync**: Track document changes, skip unchanged
- **PDF support**: Extend to non-HTML documents
- **Cost alerts**: CloudWatch alarms for budget overruns
- **Automated testing**: Integration tests for reliability

---

[← Back to Project](s3-vectors-url-embed) | [Home](index)

---

**Last updated**: January 2025
