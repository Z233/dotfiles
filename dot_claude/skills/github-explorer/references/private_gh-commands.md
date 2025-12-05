# gh CLI Commands Reference

Detailed examples and response formats for GitHub API operations.

## List Directory Contents

```bash
gh api repos/facebook/react/contents/packages
```

Response (array):
```json
[
  {
    "name": "react",
    "path": "packages/react",
    "type": "dir",
    "size": 0
  },
  {
    "name": "react-dom",
    "path": "packages/react-dom",
    "type": "dir",
    "size": 0
  }
]
```

With branch:
```bash
gh api "repos/facebook/react/contents/packages?ref=v18.2.0"
```

List root:
```bash
gh api repos/facebook/react/contents/
```

## Read File Content

```bash
gh api repos/facebook/react/contents/README.md --jq '.content' | base64 -d
```

Raw response before jq:
```json
{
  "name": "README.md",
  "path": "README.md",
  "size": 1234,
  "type": "file",
  "content": "IyBSZWFjdA0K...",
  "encoding": "base64"
}
```

With branch:
```bash
gh api "repos/facebook/react/contents/README.md?ref=main" --jq '.content' | base64 -d
```

## Get Repository Info

```bash
gh api repos/facebook/react
```

Useful fields:
```bash
gh api repos/facebook/react --jq '{
  default_branch,
  description,
  language,
  stargazers_count,
  topics
}'
```

## List Branches

```bash
gh api repos/facebook/react/branches --jq '.[].name'
```

Full response:
```bash
gh api repos/facebook/react/branches
```

## List Tags

```bash
gh api repos/facebook/react/tags --jq '.[].name'
```

## Search Repository Code

```bash
gh api "search/code?q=useState+repo:facebook/react" --jq '.items[] | {path, name}'
```

## Get Tree (recursive directory listing)

```bash
gh api "repos/facebook/react/git/trees/main?recursive=1" --jq '.tree[] | select(.type=="blob") | .path'
```

## Common jq Patterns

List only files:
```bash
gh api repos/{owner}/{repo}/contents/{path} --jq '.[] | select(.type=="file") | .name'
```

List only directories:
```bash
gh api repos/{owner}/{repo}/contents/{path} --jq '.[] | select(.type=="dir") | .name'
```

Format as tree:
```bash
gh api repos/{owner}/{repo}/contents/{path} --jq '.[] | "\(.type)\t\(.name)"'
```

## Error Handling

404 response means path doesn't exist or repo is private/doesn't exist.

Rate limits: Check `gh api rate_limit` for remaining requests.
