## Pro CTO PRD: bestcasinoportal.com

---

### 🏷️ Project Title

**BestCasinoPortal SEO Website Development**

### 📅 Date & Version

* **Date:** August 7, 2025 (Asia/Jerusalem)
* **Version:** 1.1 (Expanded Architecture & Context)

### 🎯 Objective

Design, implement, and deploy a scalable, enterprise-grade SEO casino portal inspired by Casino.ca, leveraging pre-rendered content, modular microservices, and automated CI/CD pipelines. Ensure end-to-end context-awareness, comprehensive architecture specification, and zero room for misconfiguration.

### 🔍 Scope

* **Front-end:** SEO-first, hybrid SSG/SSR React/Next.js app
* **Back-end:** Microservices in NestJS (Node+TS), Go, and Rust edge functions
* **Data & Search:** PostgreSQL, Redis, Elasticsearch
* **Infrastructure:** Terraform-provisioned cloud resources (DNS, CDN, DB, compute)
* **CI/CD & QA:** GitHub Actions with Lighthouse audits, automated tests
* **Monitoring & Alerting:** Prometheus, Grafana, Alertmanager

### 👥 Stakeholders

* **Product Owner:** The Media Ambassador (User)
* **Pro CTO Agent:** Autonomous AI agent with MCP servers
* **Dev Team:** Front‑end, back‑end, DevOps specialists
* **QA Team:** Automation & manual testers
* **Marketing:** SEO & content strategists

### 📈 Success Criteria

1. **SEO Metrics:** Lighthouse SEO score ≥ 95 on key pages; Core Web Vitals within thresholds (LCP < 2.5s, FID < 100ms).
2. **Performance:** 90th percentile TTFB < 200ms globally via CDN.
3. **Reliability:** 99.9% uptime; alerting for any downtime.
4. **Scalability:** Able to handle 10k RPS on read-heavy pages.
5. **Context Integrity:** Agent reloads full context (code, status.json) 100% before each task.

---

## 🏗️ 1. System Architecture Overview

### 1.1 Logical Architecture

1. **Presentation Layer**

   * Next.js front-end delivering pre-rendered HTML & JSON APIs
   * Dynamic client-side React hydration for interactivity

2. **API Gateway**

   * Apollo GraphQL for unified schema stitching
   * Rate-limiting and caching at the gateway

3. **Microservices Layer**

   * **User Service (NestJS)**: Authentication, user profiles, sessions
   * **Casino Service (Go)**: Casino metadata, comparison logic, bonus calculations
   * **Content Service (Node+TS)**: Article management, CMS integration
   * **Edge Functions (Rust/WebAssembly)**: JSON-LD rendering, security checks

4. **Data Layer**

   * **PostgreSQL Cluster**: Primary relational store, JSONB content fields
   * **Redis Cluster**: Caching of rendered pages, session tokens, rate limit counters
   * **Elasticsearch Cluster**: Search index for casinos, articles, FAQs

5. **Infrastructure & Cloud**

   * **Cloudflare CDN**: Global caching, SSL termination, WAF rules
   * **Kubernetes (EKS/GKE)**: Orchestration of containerized microservices
   * **Terraform State (S3 + DynamoDB Locking)**: IaC management

6. **CI/CD & Automation**

   * **GitHub Actions Workflows**: Build, test, lint, SEO audit, deploy
   * **Docker Registry**: Host container images
   * **Helm Charts**: Kubernetes deployment descriptors

7. **Monitoring & Logging**

   * **Prometheus**: Metrics collection (app, infra)
   * **Grafana**: Dashboards for metrics visualization
   * **ELK Stack**: Centralized log aggregation and querying

### 1.2 Physical Architecture

* **Region:** Primary in EU-Central (closest to Canada traffic origin for SEO parity)
* **Compute Nodes:** 3× m5.large (8 vCPU, 32 GB RAM) Kubernetes nodes
* **Database:** Managed PostgreSQL with multi-AZ failover
* **Caching:** Redis cluster with 3 replicas
* **Search:** Elasticsearch 7.17 with dedicated master/data nodes

---

## 🔄 2. Full Context Management

Every agent invocation MUST:

1. **Load `status.json`** from repo root.
2. **Validate** against JSON schema (fields: projectName, currentPhase, phaseStatus, lastUpdated, contextSnapshot).
3. **Git Pull** latest main branch; verify commit hash matches `contextSnapshot`.
4. **MCP Servers**: mount filesystem, connect to GitHub API, load Notion docs, confirm mem0 memory state.
5. **Abort** with clear error if any context step fails.

Example `status.json` schema:

```json
{
  "projectName": "bestcasinoportal",
  "currentPhase": 2,
  "phaseStatus": "in_progress",
  "lastUpdated": "2025-08-07T12:00:00+03:00",
  "contextSnapshot": "abc123def456"
}
```

---

## 🔧 3. Detailed Phase Breakdown

### Phase 1: Context Initialization & Planning

* **Tasks:**

  1. Load and validate `status.json`.
  2. Git sync: `git pull origin main`.
  3. MCP health check: filesystem, GitHub, mem0.
  4. Generate detailed project diagram in Notion.
* **Deliverables:** Updated `status.json` → `phaseStatus`: `complete`.

### Phase 2: SSH Connection & Security Hardening

* **Tasks:**

  1. Create SSH key pair: `ssh-keygen -t ed25519`.
  2. Copy public key to `root@193.233.161.161:/root/.ssh/authorized_keys`.
  3. Update `~/.ssh/config`:

     ```ini
     Host bestcasinoportal
       HostName 193.233.161.161
       User root
       IdentityFile ~/.ssh/id_ed25519
     ```
  4. Disable password login in `/etc/ssh/sshd_config`, restart SSH.
  5. Verify connection: `ssh bestcasinoportal`.
* **Deliverables:** `status.json` → `currentPhase`: 3, `phaseStatus`: `complete`.

### Phase 3: DNS & Cloudflare Terraform Provisioning

* **Tasks:**

  1. Write Terraform HCL: A record, CNAME, proxied mode.
  2. `terraform init && terraform apply`.
  3. Import Cloudflare token via CI secrets.
  4. Configure Full TLS Strict; enable caching rules.
  5. Purge CDN cache.
* **Deliverables:** Terraform state in S3, `status.json` updated.

### Phase 4: Compute & Container Orchestration

* **Tasks:**

  1. Define Kubernetes namespaces: `frontend`, `backend`, `infra`.
  2. Build Docker images: `Dockerfile.frontend`, `Dockerfile.backend`.
  3. Helm chart templating for services and ingress.
  4. Deploy PostgreSQL & Redis via Helm charts.
  5. Health-check all pods.
* **Deliverables:** Running clusters; update `status.json`.

### Phase 5: Front-End Development

* **Tasks:**

  1. Scaffold Next.js project with TypeScript.
  2. Install Tailwind; configure purge paths.
  3. Create page templates: `/`, `/category/[slug]`, `/casino/[id]`, `/province/[code]`.
  4. Integrate JSON-LD components (FAQ, Breadcrumb).
  5. Add meta tags via Next.js `Head` for OpenGraph and Twitter.
  6. Write Cypress E2E tests for main flows.
* **Deliverables:** PR merged; `status.json` phase complete.

### Phase 6: API & Data Services

* **Tasks:**

  1. Define GraphQL SDL: types `Casino`, `Bonus`, `Province`, `Game`.
  2. Implement NestJS resolvers and services.
  3. Develop Go service for odds & real-time data; containerize.
  4. Create indexing pipeline: ingest Postgres → Elasticsearch.
  5. Write unit tests and Postman collections.
* **Deliverables:** GraphQL endpoint live; `status.json` updated.

### Phase 7: CI/CD & Automated SEO Audits

* **Tasks:**

  1. Create GitHub Actions workflows: `build`, `test`, `lighthouse`.
  2. Configure Lighthouse CI thresholds.
  3. On failure: abort and create GitHub issue with logs.
  4. On success: deploy to staging, update `status.json`.
* **Deliverables:** Green builds & audits in PRs.

### Phase 8: Content Population & SEO Validation

* **Tasks:**

  1. Generate `sitemap.xml` via Next.js plugin.
  2. Create `robots.txt`.
  3. Populate top-level comparison table JSON files.
  4. Validate structured data in Google Rich Results Test.
  5. Submit sitemap to Search Console.
* **Deliverables:** Indexed site; initial SEO reports.

### Phase 9: Observability & Alerting

* **Tasks:**

  1. Deploy Prometheus operator and Grafana via Helm.
  2. Install Node Exporter and cAdvisor.
  3. Create dashboards: latency, error rate, resource usage.
  4. Configure Alertmanager: notify Slack/email on critical alerts.
* **Deliverables:** Live dashboards; alert rules active.

### Phase 10: Production Release & Handover

* **Tasks:**

  1. Final performance tuning (CDN rules, caching).
  2. Conduct load tests (k6 or JMeter).
  3. Compile runbooks: deployment steps, rollback procedures.
  4. Transfer credentials and documentation to stakeholders.
  5. Update `status.json` → `projectStatus`: `live`.
* **Deliverables:** Project in maintenance mode; documentation complete.

---

## 📦 4. Status Tracking: `status.json`

Agent must atomically update after each step:

```json
{
  "projectName": "bestcasinoportal",
  "currentPhase": 10,
  "phaseStatus": "complete",
  "lastUpdated": "2025-08-07T23:59:00+03:00",
  "contextSnapshot": "<new-commit-hash>",
  "errors": []
}
```

> **Note:** Any error encountered during a phase must be appended to `errors` with timestamp and error details. Agent reloads entire context before remediation.
