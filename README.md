# Listen - Personal Podcast System

A personal podcast system that converts web articles to audio files using text-to-speech. Built with a queue-based architecture on Google Cloud Platform.

## Architecture

### Components

1. **Chrome Extension** (`listen-listener/`) - Queues URLs from "listen" tab group to Supabase
2. **Chrome VM Queue Processor** (`terraform/modules/chrome_vm/queue_processor.py`) - Processes queued URLs through headless Chrome
3. **Cloud Functions** (`functions/`) - Serverless processing pipeline (upload, TTS, RSS, download, cleaner)
4. **Infrastructure** (`terraform/`) - GCP + Supabase deployment with Terraform

### Processing Flow

```
Chrome Extension í Supabase url_queue (pending)
                         ì
                   Chrome VM Queue Processor (systemd service)
                         ì (Chrome DevTools Protocol extracts HTML)
                   Upload Function í Pub/Sub í TTS Function í Supabase Storage
                         ì                                          ì
                   Supabase Database                    RSS Feed ê Download Function
                                                                     ì
                                                         Cleaner (weekly cleanup)
```

### Queue-Based Processing

**url_queue table**: Tracks URL processing lifecycle
- `pending` í `processing` í `completed`/`failed`
- Indexed on `(status, created_at)` for efficient polling
- Stores error messages for failed URLs

**Queue Processor**: Systemd service running on Chrome VM
- Polls Supabase for pending URLs (oldest first)
- Opens URLs in headless Chrome on port 9222
- Extracts HTML via Chrome DevTools Protocol WebSocket
- POSTs to upload function with URL + HTML
- Updates queue status throughout processing

**Local Queue Processing**: For clearing large backlogs
- Terraform generates `desktop-config.json` with Supabase credentials
- Load extension locally in Chrome to process queue faster than VM
- Same extension code works both on VM and desktop

## Tech Stack

- **Python 3.13** with `uv` for dependency management
- **Google Cloud Platform** (Functions, Pub/Sub, TTS, Compute Engine)
- **Supabase** (PostgreSQL database + file storage)
- **Terraform** for infrastructure as code
- **Chrome Extension Manifest V3** + Chrome DevTools Protocol
- **Systemd** for service management on Debian 12 VM

## Development Commands

### Local Function Testing

```bash
uv run main.py upload        # Test upload function
uv run main.py tts           # Test TTS function
uv run main.py rss           # Test RSS feed generation
uv run main.py download      # Test file download
uv run main.py cleaner       # Test file cleanup
```

### Linting

```bash
uvx ruff check --fix <file>  # Fix linting issues
uvx ruff format <file>       # Format code
uv run mypy <file>           # Type checking
```

### Chrome Extension Development

```bash
# Load extension in Chrome
# chrome://extensions/ í Load unpacked í select listen-listener/

# For local queue processing (clearing backlogs)
# 1. Run: terraform -chdir=terraform apply
# 2. Load extension with generated desktop-config.json
# 3. Extension will queue URLs to Supabase directly
```

### Infrastructure Management

```bash
terraform -chdir=terraform init      # Initialize Terraform
terraform -chdir=terraform plan      # Preview changes
terraform -chdir=terraform apply     # Deploy infrastructure
terraform -chdir=terraform destroy   # Destroy all resources
```

### Dependencies

```bash
uv sync --all-packages              # Install dependencies
uv sync --all-packages --group dev  # Include dev dependencies
```

## Infrastructure

### Chrome VM

**Systemd Services**:
- `chrome-remote.service`: Headless Chrome with DevTools Protocol (port 9222)
- `queue-processor.service`: URL queue processor (polls Supabase)
- `chrome-periodic.timer`: Restarts Chrome every configurable period (6H/1D/15m)

**Setup**: Automated via Terraform
- Installs Chrome, VNC, Python dependencies
- Configures extension with Supabase credentials
- Starts queue processor as systemd service

### Cloud Functions

| Function | Memory | Timeout | Trigger | Purpose |
|----------|--------|---------|---------|---------|
| upload   | 512Mi  | 120s    | HTTP    | Parse HTML, store in DB |
| tts      | 512Mi  | 540s    | Pub/Sub | Generate audio files |
| download | 256Mi  | 60s     | HTTP    | Serve audio + track usage |
| rss      | 256Mi  | 30s     | HTTP    | Serve podcast feed |
| cleaner  | 256Mi  | 300s    | Scheduler | Remove expired files (weekly) |

### Supabase

**Tables**:
- `listen`: Podcast metadata (guid, title, audio_url, timestamps)
- `url_queue`: URL processing queue with status tracking
- `character_count`: TTS usage tracking for cost management

**Storage**: Audio files with 7-day TTL from last download

### Environment Variables

Functions require:
- `SUPABASE_URL`: Supabase project URL
- `SUPABASE_KEY`: Supabase service key
- `GCP_PROJECT`: Google Cloud project ID
- `PUBSUB_TOPIC_TTS`: Pub/Sub topic for TTS processing

## TTS Cost Management

Intelligent cost control:
- Google Cloud TTS (paid, better quality) until 4M chars/month
- Fallback to gTTS (free) after limit
- Character usage tracked by month/year in database

## File Lifecycle

1. **Queue**: Chrome extension adds URL to Supabase queue
2. **Extract**: VM queue processor opens URL in Chrome, extracts HTML
3. **Upload**: HTML parsed with `justext`, stored in database
4. **TTS**: Audio generated and uploaded to Supabase storage
5. **RSS**: Podcast feed served with download links
6. **Download**: Audio files served, `last_downloaded` timestamp updated
7. **Cleanup**: Files deleted 7 days after last download

## Workspace Structure

`uv` workspace with root `pyproject.toml` and function-specific configs:
- `functions/cleaner`
- `functions/download`
- `functions/rss`
- `functions/tts`
- `functions/upload`
