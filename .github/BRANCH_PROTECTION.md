# Branch Protection Setup

Run this once from your terminal to protect the `main` branch:

```bash
gh api repos/Sparklestone/FullBars/branches/main/protection \
  --method PUT \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Xcode test + coverage gate"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null
}
JSON
```

This requires CI to pass before merging to `main`. Adjust `enforce_admins` to `true` if you want the rule to apply to repo owners too.
