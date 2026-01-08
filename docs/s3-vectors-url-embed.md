---
layout: default
title: S3 Vectors URL Embed
---

# S3 Vectors URL Embed

Production-ready infrastructure for building AWS Bedrock Knowledge Bases from web documentation.

[View on GitHub](https://github.com/cakeisgoodforyou/s3-vectors-url-embed) • [See Architecture](s3-vectors-architecture)

---

## Overview

Automatically fetches, processes, and embeds web documentation for RAG systems using AWS Bedrock, with **90% cost savings** compared to traditional OpenSearch solutions.

### The Problem
AWS Bedrock Knowledge Bases traditionally require OpenSearch Serverless ($35-40/month minimum) for vector storage—prohibitive for portfolio projects and small-scale deployments.

### The Solution
Uses AWS S3 Vectors (released Dec 2024) for pay-per-GB storage, reducing costs to ~$2-5/month while maintaining production-ready reliability.

---

## Key Features

✅ **Cost Optimized**: 90% cheaper than OpenSearch  
✅ **Fully Automated**: One command deployment with Terraform  
✅ **Handles Large Files**: Intelligent splitting with context preservation  
✅ **Production Security**: Least privilege IAM, encryption, no hardcoded secrets  
✅ **Clean Embeddings**: HTML → Plain text processing for meaningful results

---

## Quick Start

```bash
# Clone and deploy
git clone https://github.com/cakeisgoodforyou/s3-vectors-url-embed.git
cd s3-vectors-url-embed/terraform
terraform init
terraform apply

# Test with a URL
aws lambda invoke \
  --function-name s3-vectors-url-embed-dev-fetch-docs \
  --payload '{"urls": ["https://docs.stripe.com/api"]}' \
  response.json

# Query the knowledge base
aws bedrock-agent-runtime retrieve \
  --knowledge-base-id $(terraform output -raw knowledge_base_id) \
  --retrieval-query text="How do I authenticate?" \
  --region us-east-1
```

---

## What Gets Deployed

| Component | Purpose | Cost/Month |
|-----------|---------|------------|
| Lambda Function | Fetch & process URLs | $0.20 |
| S3 Bucket (docs) | Store cleaned text | $0.05 |
| S3 Vectors | Store embeddings | $0.50-2 |
| Bedrock KB | RAG orchestration | $1.00 |
| **Total** | | **~$2/month** |

---

## Technical Highlights

### 1. File Splitting for Bedrock Sync
**Challenge**: S3 Vectors has a 2KB filterable metadata limit. Large files caused sync failures.

**Solution**: Split files at 400KB boundaries while preserving headers for context:

```
# Original H1
## Original H2

---
**Part 2 of 3**
---

[content continues with full context]
```

### 2. Plain Text Extraction
Processes HTML into clean text to avoid JSON/HTML fragments in embeddings:
- Extract main content
- Fix encoding issues (mojibake)
- Normalize Unicode
- Remove code blocks
- Clean whitespace

### 3. Non-Filterable Metadata
Critical configuration for S3 Vectors:

```terraform
nonFilterableMetadataKeys = [
  "x-amz-bedrock-kb-source-uri",
  "x-amz-bedrock-kb-chunk-id",
  "S3VECTORS-EMBED-SRC-CONTENT"
]
```

Without this, large metadata exceeds the 2KB limit and sync fails.

---

## Architecture

```
URL → Lambda → Clean HTML → Split if >400KB → S3 (docs)
                                                  ↓
                                        Bedrock KB Sync
                                                  ↓
                                      Titan Embeddings
                                                  ↓
                                      S3 Vectors (256-dim)
                                                  ↓
                                           RAG Queries
```

[Detailed Architecture →](s3-vectors-architecture)

---

## Skills Demonstrated

**Infrastructure as Code**
- Terraform with latest AWS provider features
- Resource dependencies and lifecycle management
- Cost optimization strategies

**AWS Bedrock / GenAI**
- Knowledge Base configuration
- S3 Vectors (brand new feature)
- Titan Embeddings optimization
- RAG pattern implementation

**Problem Solving**
- Debugging opaque AWS error messages
- Working with incomplete documentation (S3 Vectors is 1 month old)
- Iterative solution refinement
- Production-ready error handling

**Python Engineering**
- Lambda function optimization
- HTML processing with BeautifulSoup
- Intelligent content chunking
- Unicode/encoding handling

---

## Use Cases

This infrastructure enables:
- **API Documentation Assistants**: Query multiple API docs with natural language
- **Internal Knowledge Bases**: Index company policies and procedures
- **Technical Research Agents**: Foundation for code generation systems
- **Documentation Search**: Add semantic search to any docs site

---

## Cost Comparison

| Solution | Dev (~1GB) | Production (~100GB) |
|----------|-----------|---------------------|
| **S3 Vectors** | $2/month | $24/month |
| OpenSearch Serverless | $35/month | $50+/month |
| **Savings** | **94%** | **52%+** |

---

## Lessons Learned

**Early Adoption Pays Off**: S3 Vectors was released in December 2024. Despite limited documentation and Terraform support, implementing it early resulted in massive cost savings and a unique portfolio piece.

**Metadata Matters**: Understanding the 2KB filterable metadata limit in S3 Vectors was critical. The solution (marking large fields as non-filterable) isn't documented anywhere but was essential for reliability.

**Context Preservation**: When splitting files, maintaining headers in each part ensures embeddings understand the context, dramatically improving retrieval quality.

---

## Future Enhancements

- [ ] Support for PDF/Word documents
- [ ] Incremental sync (skip unchanged URLs)
- [ ] Multi-region deployment
- [ ] Automated testing with pytest
- [ ] GitHub Actions CI/CD

---

## Links

- [GitHub Repository](https://github.com/cakeisgoodforyou/s3-vectors-url-embed)
- [Architecture Details](s3-vectors-architecture)
- [← Back to Projects](index)

---

**Built January 2025** | MIT License