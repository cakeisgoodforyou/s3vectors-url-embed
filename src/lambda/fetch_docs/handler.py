"""
Lambda function to fetch URLs and store in S3.
Optimized for Bedrock Knowledge Base sync - splits large files with context preservation.

Key features:
- Splits files >400KB to avoid S3Vectors metadata limits
- Preserves headers in each part for context
- Plain-text ingestion with encoding fixes
- H1-based logical splitting
- Minimal metadata to prevent 2KB filterable limit issues
"""

import json
import boto3
import requests
from urllib.parse import urlparse
from datetime import datetime
from bs4 import BeautifulSoup
import hashlib
import os
import re
import unicodedata
from ftfy import fix_text

s3_client = boto3.client("s3")

BUCKET_NAME = os.environ["DOCS_BUCKET"]
MAX_FILE_SIZE = 400_000  # 400KB - safe for Bedrock sync
HEADER_OVERLAP = 500  # Characters of headers to include in continuation parts


def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    if "parameters" in event:
        params = {p["name"]: p["value"] for p in event["parameters"]}
        urls = json.loads(params.get("urls", "[]"))
        prefix = params.get("prefix", "api-docs")
    else:
        urls = event.get("urls", [])
        prefix = event.get("prefix", "api-docs")

    if not urls:
        return {"statusCode": 400, "body": json.dumps({"error": "No URLs provided"})}

    results, errors = [], []

    for url in urls:
        try:
            results.extend(fetch_and_store_url(url, prefix))
        except Exception as e:
            errors.append(f"{url}: {str(e)}")

    return {
        "statusCode": 200 if not errors else 207,
        "body": json.dumps(
            {
                "files_created": len(results),
                "errors": errors,
                "results": results,
            }
        ),
    }


# -------------------------
# Cleaning
# -------------------------

def clean_html_content(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")

    for el in soup(["script", "style", "nav", "header", "footer", "iframe", "noscript"]):
        el.decompose()

    main = soup.select_one("main, article, [role=main], .content, #content") or soup.body
    parts = []

    for el in main.find_all(["h1", "h2", "h3", "p", "li"]):
        text = el.get_text(" ", strip=True)
        if not text:
            continue

        if el.name.startswith("h"):
            level = int(el.name[1])
            parts.append(f"\n\n{'#' * level} {text}\n")
        else:
            parts.append(text)

    text = "\n".join(parts)

    # Fix mojibake FIRST
    text = fix_text(text)

    # Unicode normalization
    text = unicodedata.normalize("NFKC", text)

    # Replace smart quotes explicitly
    text = text.replace("'", "'").replace(""", '"').replace(""", '"')

    # Remove code blocks (they often cause metadata bloat)
    text = re.sub(r"```[\s\S]*?```", "", text)

    # Redact API keys
    text = re.sub(r"sk_(test|live)_[A-Za-z0-9]+", "sk_REDACTED", text)

    # Whitespace cleanup
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"[ \t]+", " ", text)

    return dedupe_blocks(text.strip())


def dedupe_blocks(text: str) -> str:
    seen, out = set(), []
    for block in text.split("\n\n"):
        h = hashlib.md5(block.encode("utf-8")).hexdigest()
        if h not in seen:
            seen.add(h)
            out.append(block)
    return "\n\n".join(out)


# -------------------------
# H1 splitting
# -------------------------

def split_by_h1(text: str):
    sections = re.split(r"\n(?=# )", text)
    output = []

    for section in sections:
        lines = section.strip().splitlines()
        if not lines:
            continue

        title = re.sub(r"[^a-z0-9]+", "-", lines[0].lower()).strip("-")
        output.append({"title": title or "section", "content": section.strip()})

    return output


def extract_headers(text: str, max_chars: int = HEADER_OVERLAP) -> str:
    """
    Extract the leading headers (H1, H2, H3) from text for context preservation.
    Returns up to max_chars of headers.
    """
    lines = text.split('\n')
    headers = []
    char_count = 0
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
        
        # Check if it's a header (starts with #)
        if line.startswith('#'):
            if char_count + len(line) > max_chars:
                break
            headers.append(line)
            char_count += len(line) + 1
        else:
            # Stop at first non-header content
            break
    
    return '\n'.join(headers)


def split_large_content(content: str, section_title: str, max_size: int = MAX_FILE_SIZE) -> list:
    """
    Split large content into parts with header preservation.
    Each part includes:
    - Original headers for context
    - Part indicator
    - Content chunk
    """
    content_bytes = content.encode('utf-8')
    
    # If small enough, return as single piece
    if len(content_bytes) <= max_size:
        return [content]
    
    # Extract headers for context preservation
    headers = extract_headers(content)
    
    # Split by paragraphs
    paragraphs = content.split('\n\n')
    
    # Build parts
    parts = []
    current_part = []
    current_size = 0
    part_num = 1
    
    # Reserve space for headers and part indicator in each chunk
    header_overhead = len(headers.encode('utf-8')) + 100  # 100 for part indicator
    available_size = max_size - header_overhead
    
    for para in paragraphs:
        para_size = len(para.encode('utf-8'))
        
        # If single paragraph is too large, split it
        if para_size > available_size:
            # Save current part if any
            if current_part:
                parts.append('\n\n'.join(current_part))
                current_part = []
                current_size = 0
            
            # Split the large paragraph by sentences
            sentences = re.split(r'(?<=[.!?])\s+', para)
            for sentence in sentences:
                sentence_size = len(sentence.encode('utf-8'))
                
                if current_size + sentence_size > available_size and current_part:
                    parts.append('\n\n'.join(current_part))
                    current_part = [sentence]
                    current_size = sentence_size
                else:
                    current_part.append(sentence)
                    current_size += sentence_size
        
        # Normal paragraph handling
        elif current_size + para_size > available_size and current_part:
            # Start new part
            parts.append('\n\n'.join(current_part))
            current_part = [para]
            current_size = para_size
        else:
            current_part.append(para)
            current_size += para_size
    
    # Add remaining content
    if current_part:
        parts.append('\n\n'.join(current_part))
    
    # If only one part, return as-is
    if len(parts) == 1:
        return parts
    
    # Add headers and part indicators to each part
    formatted_parts = []
    total_parts = len(parts)
    
    for i, part_content in enumerate(parts, 1):
        # Build part with context
        part_text = f"{headers}\n\n---\n**Part {i} of {total_parts}**\n---\n\n{part_content}"
        formatted_parts.append(part_text)
        
        print(f"Created part {i}/{total_parts} for section '{section_title}': {len(part_text.encode('utf-8'))} bytes")
    
    return formatted_parts


# -------------------------
# Fetch + store
# -------------------------

def fetch_and_store_url(url: str, prefix: str):
    resp = requests.get(url, headers={"User-Agent": "s3-vectors-url-embed/1.0"}, timeout=30)
    resp.raise_for_status()
    resp.encoding = resp.apparent_encoding or "utf-8"

    content = clean_html_content(resp.text)
    sections = split_by_h1(content)

    parsed = urlparse(url)
    domain = parsed.netloc.replace(".", "_")
    # Keep the URL path structure clean
    url_path = parsed.path.strip("/") or "index"
    url_hash = hashlib.md5(url.encode()).hexdigest()[:8]
    date = datetime.utcnow().strftime("%Y%m%d")

    files = []

    for i, section in enumerate(sections):
        # Split section if it's too large
        content_parts = split_large_content(
            section["content"], 
            section["title"],
            MAX_FILE_SIZE
        )

        for j, part_content in enumerate(content_parts):
            # Clean file naming: domain/path/section/part_hash_date.txt
            if len(content_parts) == 1:
                # Single part: docs_stripe_com/api/authentication/section-title_abc123_20260107.txt
                key = f"{domain}/{url_path}/{section['title']}_{url_hash}_{date}.txt"
            else:
                # Multi-part: docs_stripe_com/api/authentication/section-title/part1of3_abc123_20260107.txt
                key = f"{domain}/{url_path}/{section['title']}/part{j+1}of{len(content_parts)}_{url_hash}_{date}.txt"

            put_object(key, part_content.encode("utf-8"))
            
            files.append({
                "s3_key": key,
                "size_bytes": len(part_content.encode("utf-8")),
                "is_part": len(content_parts) > 1,
                "part_info": f"{j+1}/{len(content_parts)}" if len(content_parts) > 1 else "1/1"
            })

    return files


def put_object(key: str, body: bytes):
    s3_client.put_object(
        Bucket=BUCKET_NAME,
        Key=key,
        Body=body,
        ContentType="text/plain",
        Metadata={"source": "url-docs"}  # Minimal metadata
    )