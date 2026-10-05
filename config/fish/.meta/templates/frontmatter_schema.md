# Graph Database Ingestion Protocol & Frontmatter Schema

For an AI Agent to parse and register this codebase as an atomic graph database:

## 1. Node Identification
Each `.fish` or `.md` file containing `# ---` to `# ---` (or `---` for markdown) represents a `DocumentNode` (or `AtomicNote`).

## 2. Metadata Extraction
A YAML parser must read the frontmatter block.
For `.fish` files, strip `# ` from each line to form standard YAML:
```yaml
---
title: Node Title
module: relative/path/to/file.fish
layer: Layer Name
responsibility: Description of purpose
dependencies: [list, of, dependencies]
backlinks: [list, of, backlink, referrers]
created_at: YYYY-MM-DD
updated_at: YYYY-MM-DD
tags: [tag1, tag2]
---
```

## 3. Edge Creation
*   Create directional dependency edges `(SourceNode)-[:DEPENDS_ON]->(TargetNode)` based on the `dependencies` array.
*   Create directional referrer edges `(TargetNode)-[:REFERRED_BY]->(SourceNode)` based on the `backlinks` array.

## 4. Implicit Associations
*   Create tag nodes and associate documents using `(DocumentNode)-[:HAS_TAG]->(TagNode)`.
