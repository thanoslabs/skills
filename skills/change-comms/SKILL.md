---
name: change-comms
description: >
  Write short, copy-pastable announcements of code changes for team chat
  (Slack, Teams, Discord) or status updates: review requests for open PRs,
  "what shipped" updates for merged work, and standup summaries. Use when
  the user asks to "write a Slack message for these PRs", "announce my
  PRs", "ask for review", "what did I ship this week", "write my standup
  update", or when another skill (e.g. coordinate) hands over a list of PRs
  to announce.
---

# Change Comms

Turn a set of changes into a message a person can paste into chat as-is.
Output text only; post it nowhere unless the user explicitly asks.

## 1. Gather the changes

Use the first source that applies:

1. **Given list** - PRs passed by the user or a calling skill. Each item
   needs a URL; a few-word summary, title, ticket, and draft flag are
   optional.
2. **PR references** - numbers or URLs: read each with
   `gh pr view <ref> --json url,title,isDraft,state,body`.
3. **Query** - the user's own PRs:

   ```sh
   gh search prs --author=@me --state=open --json url,title,isDraft,repository
   gh search prs --author=@me --merged-at=">=<YYYY-MM-DD>" --json url,title,repository
   ```

   Use the open query for review requests and standups, the merged query
   for shipped updates. Confirm the list with the user if the query
   returned anything they might not want announced.

## 2. Pick the format

Infer the purpose from the request; default to **review request**.

**Review request** (open PRs):

```
PRs for PROJ-123 - Retry webhook deliveries with backoff:
• https://github.com/acme/api/pull/42 - add backoff config
• https://github.com/acme/worker/pull/7 - wire retries into worker
```

**Shipped** (merged PRs):

```
Shipped PROJ-123 - Retry webhook deliveries with backoff:
• https://github.com/acme/api/pull/42 - add backoff config
• https://github.com/acme/worker/pull/7 - wire retries into worker
```

**Standup** (mixed states, grouped):

```
Merged:
• https://github.com/acme/api/pull/42 - add backoff config
In review:
• https://github.com/acme/worker/pull/7 - wire retries into worker
```

## 3. Write it

- **Header:** when the items share a ticket, use `<KEY> - <ticket title>`;
  otherwise a few words naming the shared goal. Omit the header for a
  single unrelated PR: `Review please: <url> - <summary>`.
- **One bullet per PR:** `• <url> - <summary>`. Use bare URLs; chat apps
  link and unfurl them.
- **Summary:** 2-6 words, lowercase, starting with a verb ("add backoff
  config"). Use the given summary if there is one; otherwise shorten the
  PR title, dropping the Conventional Commits prefix.
- **Order:** the given order (e.g. dependency order); otherwise group by
  repo, oldest first.
- **Drafts:** if some but not all PRs are drafts, append ` (draft)` to
  those bullets.
- **Pending items:** if a caller lists items without a PR yet, leave them
  out of the message and list them under it as "not yet published".
- Use a plain hyphen as the separator, not an em or en dash. No emoji or
  @-mentions unless the user asks; mentions notify people.
- Never include secrets, local paths, or internal hostnames from PR text.

Present the message in a fenced code block so it copies cleanly.

## Posting (only on explicit request)

If the user asks you to post it and a chat integration is available:
confirm the destination channel, check its description for posting rules,
then post. Otherwise say no integration is available and leave the
message for them to paste.
