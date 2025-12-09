# TwinSpin - Database Reconciliation Service Plan

## Project Overview
High-scale database reconciliation service for comparing billions of rows between DB2 and Oracle databases.
Technical/developer-focused UI with monospace fonts, terminal aesthetics, and real-time metrics.

## Completed Steps
- [x] Generate Phoenix LiveView project "twinspin"
- [x] Create detailed plan.md
- [ ] Start server for live development

## Detailed Implementation Plan

### Phase 1: Initial Setup & Static Mockup (Steps 3-4)
- [ ] Start the Phoenix server to view progress
- [ ] Replace home.html.heex with technical-themed static mockup
  - Dark terminal-inspired color scheme
  - Monospace fonts for code/data display
  - Mock dashboard showing job queue, partition tree, diff viewer
  - Navigation for Jobs, Partitions, Results, Settings

### Phase 2: Core Data Models (Steps 5-6)
- [ ] Create Ecto schemas and migrations (2 steps combined)
  - ReconciliationJob schema
    - source_db (type, connection_string, table, columns)
    - target_db (type, connection_string, table, columns)
    - partition_strategy (row_count_threshold, max_depth)
    - status (pending, running, completed, failed)
    - started_at, completed_at
    - total_rows, processed_rows, discrepancies_found
  - Partition schema
    - belongs_to job
    - partition_key (range boundaries)
    - depth, status
    - row_count_estimate
    - parent_partition_id (for tree structure)
  - DiscrepancyResult schema
    - belongs_to partition
    - discrepancy_type (missing_source, missing_target, value_mismatch)
    - row_identifier (JSON of key fields)
    - field_diffs (JSON of field-level differences)

### Phase 3: Dashboard LiveView (Steps 7-9)
- [ ] Implement ReconciliationLive.Index (main dashboard)
  - Real-time job list with streams
  - PubSub for live status updates
  - Job metrics: total jobs, running, completed, failed
  - Create new job form with validation
  - Job configuration: source/target DB settings, partition strategy
- [ ] Implement job list template
  - Table with monospace font showing jobs
  - Status indicators with progress bars
  - Actions: view details, cancel, delete
- [ ] Wire up PubSub broadcasting for job status changes
  - Broadcast on job start, progress, completion

### Phase 4: Job Detail View (Steps 10-11)
- [ ] Implement ReconciliationLive.Show (job detail page)
  - Partition tree visualization (ASCII tree or nested divs)
  - Real-time progress tracking per partition
  - Discrepancy list with filtering
  - Diff viewer for field-level mismatches
- [ ] Create job detail template
  - Partition tree with expand/collapse
  - Discrepancy table with syntax highlighting for diffs
  - Export results (CSV, JSON)

### Phase 5: Design Integration (Steps 12-13)
- [ ] Update assets/css/app.css with technical theme
  - Dark terminal color palette
  - Monospace font stack (Fira Code, JetBrains Mono, Consolas)
  - Custom daisyUI theme configuration
  - Syntax highlighting colors for diffs
- [ ] Update root.html.heex and <Layouts.app>
  - Force dark theme
  - Remove default Phoenix branding
  - Add technical-themed header/nav
  - Integrate layouts seamlessly

### Phase 6: Router & Testing (Steps 14-15)
- [ ] Update router with new routes
  - Replace placeholder "/" with ReconciliationLive.Index
  - Add "/jobs/:id" for ReconciliationLive.Show
- [ ] Compile check and visit app
  - Verify all routes work
  - Test real-time updates
  - Check responsive design

### Phase 7: Reserved for Debugging (Steps 16-18)
- [ ] 3 steps reserved for unexpected issues

## Key Technical Features
- **Divide & Conquer Algorithm**: Recursive partitioning for billion-row datasets
- **Real-time Updates**: PubSub for live job/partition status
- **Fault Tolerance**: Handle ODBC driver failures gracefully
- **In-Memory Processing**: High-performance dataframe operations
- **Developer UX**: Terminal-inspired, monospace, detailed logs

## Tech Stack
- Phoenix LiveView 1.1+
- Tailwind CSS with custom theme
- DaisyUI components
- Heroicons
- SQLite (dev), PostgreSQL (production ready)
- PubSub for real-time features
