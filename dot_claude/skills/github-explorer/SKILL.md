---
name: github-explorer
description: |
  Browse and read source code from public GitHub repositories using gh CLI.
  Use when: (1) exploring a GitHub repo's source code, (2) reading files from a GitHub URL,
  (3) listing directory contents of a repo, (4) navigating repo file structure,
  (5) user provides a github.com URL and wants to see the code.
---

# GitHub Explorer

Browse source code from public GitHub repositories using the `gh` CLI.

## Prerequisites

The `gh` CLI must be installed and authenticated (`gh auth status`).

## URL Parsing

Extract `owner`, `repo`, `branch`, and `path` from GitHub URLs:

| URL Pattern | Example |
|-------------|---------|
| `github.com/{owner}/{repo}` | `github.com/facebook/react` |
| `github.com/{owner}/{repo}/tree/{branch}/{path}` | `github.com/facebook/react/tree/main/packages` |
| `github.com/{owner}/{repo}/blob/{branch}/{path}` | `github.com/facebook/react/blob/main/README.md` |

## Core Operations

### List directory contents

```bash
gh api repos/{owner}/{repo}/contents/{path}
# With specific branch:
gh api "repos/{owner}/{repo}/contents/{path}?ref={branch}"
```

Returns JSON array with `name`, `type` (file/dir), `path`, `size`.

### Read file content

```bash
gh api repos/{owner}/{repo}/contents/{path} --jq '.content' | base64 -d
# With specific branch:
gh api "repos/{owner}/{repo}/contents/{path}?ref={branch}" --jq '.content' | base64 -d
```

### Get repo info

```bash
gh api repos/{owner}/{repo} --jq '{default_branch, description, language}'
```

### List branches

```bash
gh api repos/{owner}/{repo}/branches --jq '.[].name'
```

## Workflow

1. Parse URL to extract owner/repo/branch/path
2. If no branch specified, get default branch from repo info
3. List contents if path is directory, read if file
4. Navigate by updating path and repeating

## Reference

See [references/gh-commands.md](references/gh-commands.md) for detailed command examples and response formats.
