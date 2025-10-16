# Sentinel: AI Live Screen Monitor Assistant

<div align="center">
  <img src="assets/hero-sentinel.png" alt="Sentinel Banner" width="780">
</div>

<div align="center">
  <img src="https://img.shields.io/badge/Client-Swift-0A84FF">
  <img src="https://img.shields.io/badge/Server-Java%20Spring-2F933A">
  <img src="https://img.shields.io/badge/Realtime-WebSockets-black">
  <img src="https://img.shields.io/badge/AI-OpenAI-6E56CF">
  <img src="https://img.shields.io/badge/AI-Grok-111111">
  <img src="https://img.shields.io/badge/License-MIT-blue">
</div>

> **TL;DR**  
> **Sentinel** records your screen (with consent), ships captures to an **AI processor**, and returns structured **summaries, entities, tasks, and links** you can search later.  
> Built with a **Swift** client and a **Java Spring** backend. Uses **WebSockets** for live alerts/progress, and both **OpenAI** and **Grok** for multi-model analysis.  
> Backend repo will be linked here: **[Backend API → (https://github.com/superdevchi/websocketassistant/tree/main**.

---

## 🎬 Demo Video

<div align="center">
  <a href="DEMO_VIDEO_URL" target="_blank" rel="noopener noreferrer">
    <img src="assets/video-thumb-sentinel.png" alt="Watch the Sentinel demo" width="720">
  </a>
  <p><em>90-second walkthrough: consent flow → capture → AI analysis → searchable timeline.</em></p>
</div>

---

## 🧠 What It Does

- **Screen Capture (Opt-In):** User-controlled recording windows/monitors with clear consent indicators.
- **AI Extraction:** Sends frames/snippets to an AI pipeline (OpenAI + Grok) to detect **topics, entities, tasks, key quotes, links, screenshots, and timestamps**.
- **Realtime Signals:** **WebSockets** push capture status, analysis progress, and important detections (e.g., “Meeting action items found”).
- **Knowledge Timeline:** Stores findings in a **chronological, searchable timeline** for future reference.
- **Workspace Context:** Tag sessions (e.g., “Research,” “Meeting,” “Design”) and attach notes.

---

## 🏗️ Architecture (High-Level)

**Client:** Swift (macOS/iOS)  
**Server:** Java Spring (REST + WebSocket gateway)  
**AI:** OpenAI + Grok (xAI) multi-model pipeline  
**Storage:** Object storage for media (e.g., S3/GCS/MinIO) + Postgres for metadata  
**Security:** At-rest encryption, TLS in transit, optional on-device redaction

### Components

- **Swift Client**
  - Capture controller (window/monitor selection, pause/resume, consent controls).
  - Local pre-processing (optional blurs/redaction for sensitive regions).
  - Upload manager (chunked uploads, backoff/retry, bandwidth guardrails).
  - Live notifications via WebSockets (progress, detections, errors).
  - Timeline UI: sessions, keyframes, summaries, tasks, links.

- **Java Spring Backend**
  - **Ingestion API:** Authenticated endpoints for session metadata and media chunks.
  - **Processing Orchestrator:** Queues jobs, schedules AI steps, aggregates results.
  - **AI Providers:** Calls **OpenAI** and **Grok**; ensembles and reconciles outputs.
  - **WebSocket Gateway:** Emits `capture.status`, `analysis.progress`, `analysis.finding`, `error` events.
  - **Storage Layer:** Media to object storage; metadata and findings to Postgres.
  - **Search:** Indexed entities, topics, tasks, and timestamps for fast retrieval.

---

## 🔄 Data Flow (Simplified)

1. **Start session** in Swift client → user selects screen/window and gives consent.  
2. **Capture & upload** frames/snippets + metadata → Java Spring ingestion.  
3. **Orchestrate analysis** across **OpenAI** and **Grok** (OCR, topic detection, summarization, action extraction).  
4. **Emit realtime events** via **WebSockets** (status, progress, important findings).  
5. **Persist outputs**: timelines, entities, tasks, keyframes, and links.  
6. **Review & search** later in the app; export/share selected findings if desired.

---

## 🔐 Privacy, Safety & Consent

- **Explicit Consent:** Recording only begins after clear opt-in; persistent on-screen indicator while active.
- **Scoping:** User chooses **which window/monitor**; quick mute/pause controls; session-level retention settings.
- **Redaction:** Optional on-device blurs (e.g., emails, faces, numeric patterns) before upload.
- **Minimal Retention:** Configurable retention (e.g., 7/30/90 days) with **one-click delete** and “never upload” per-app rules.
- **Security:** TLS in transit; at-rest encryption for media and metadata; scoped tokens; signed URLs for media access.
- **Compliance-Ready:** Audit logs for access; data export to user; model prompts exclude secret keys.

---

## 📱 App Behavior

- **Realtime notifications** for capture/analysis via WebSockets (opt-in, rate-limited).
- **Snapshot-first UX:** Finalized summaries + keyframes are the source of truth; live signals enhance awareness but aren’t required to work.
- **Searchable timeline:** Filter by date, entities, app/source, tags, and detected tasks.
- **Exports:** Copy summaries, export CSV/JSON of findings, or save selected screenshots.

---

## 🗂 Suggested Data Model (Conceptual)

- **sessions**: id, user_id, title/tags, source (app/window/monitor), started_at, ended_at, retention_policy, consent_flags  
- **captures**: id, session_id, media_uri, duration_ms, hash, redaction_mask, created_at  
- **analyses**: id, session_id, provider (`openai|grok`), status, metrics, started_at, finished_at  
- **findings**: id, session_id, type (`summary|entity|task|quote|link|keyframe`), payload(jsonb), at_timestamp  
- **entities**: id, session_id, name, kind (`person|org|file|topic`), first_seen, last_seen  
- **events**: id, session_id, kind (`capture.status|analysis.progress|analysis.finding|error`), payload, created_at

> **Note:** Use Postgres for metadata (with proper indexing) and S3/GCS/MinIO for large media. Enforce per-user row-level access and sign media URLs.

---

## 🔗 Integrations

- **OpenAI:** OCR (via vision), topic clustering, abstractive summaries, entity/action extraction, reasoning checks.  
- **Grok (xAI):** Cross-provider reasoning, alt summaries, entity disambiguation, and hallucination cross-checks.  
- **WebSockets:** Live capture/analysis signals; retry/backoff and heartbeats.  
- **Object Storage:** Screenshots/clips; lifecycle rules for retention and deletion.  
- **Postgres:** Durable metadata and search indices.

---

## 🧭 User Journeys

- **Research Session:** Start recording a browser window → AI extracts topics/links → timeline shows keyframes and sources → you search later by keyword or entity.  
- **Meetings:** Record slides/call → AI captures **action items**, dates, names → timeline groups tasks with timestamps for follow-up.  
- **Design Work:** Capture tool panels and artboards → AI detects versions and export steps → searchable workflow references.

---

## 🗺️ Roadmap

- On-device embeddings for private/local search  
- Team spaces & shared timelines (RBAC)  
- PII detection & policy packs (finance/healthcare)  
- App-level “never record” rules and global hotkeys  
- Cross-device sync and delta uploads

---

## 🔗 Repositories

- **Backend (Java Spring):** https://github.com/superdevchi/websocketassistant/tree/main )  
- **Client (Swift):** current repo

---

## 📄 License

MIT © You
