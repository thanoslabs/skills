#!/usr/bin/env bash
# coordinate helper: locates per-item state and reports a work item's
# stage as observed from git and GitHub.
#
# Requires: bash, git, jq. Optional: gh (authenticated). Without gh, remote
# facts are reported as null and the stage falls back to state.json.
#
# Usage:
#   coordinate.sh dir <id>      print the item's state directory (not created)
#   coordinate.sh status <id>   print observed facts and derived stage as JSON
#   coordinate.sh list          list items for the current repository
#   coordinate.sh checks <id>   run the item's recorded checks in its worktree;
#                            writes checks.md and checks.log, exits 1 on failure
#   coordinate.sh prs <group>   print a group's PRs (all repos) as JSON for change-comms
#
# Run from inside the target repository (any worktree). `prs` works from
# anywhere.
set -euo pipefail

die() { echo "coordinate.sh: $*" >&2; exit 1; }

state_root() {
  echo "${COORDINATE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/coordinate}"
}

# owner-repo from the origin remote; falls back to the top-level dir name.
repo_key() {
  local url
  if url=$(git remote get-url origin 2>/dev/null); then
    url=${url%.git}
    url=${url%/}
    echo "$url" | awk -F'[/:]' '{ print $(NF-1) "-" $NF }'
  else
    basename "$(git rev-parse --show-toplevel)"
  fi
}

check_id() {
  [[ "${1:-}" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || die "invalid id '${1:-}' (want kebab-case, e.g. issue-123)"
}

item_dir() { echo "$(state_root)/$(repo_key)/$1"; }

have_gh() { command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; }

cmd_status() {
  local id=$1 dir state stage="new" branch="" base="main" publish=true worktree=""
  dir=$(item_dir "$id")
  state="$dir/state.json"

  if [[ -f "$state" ]]; then
    stage=$(jq -r '.stage // "define"' "$state")
    branch=$(jq -r '.branch // ""' "$state")
    base=$(jq -r '.base // "main"' "$state")
    publish=$(jq -r 'if .publish == false then "false" else "true" end' "$state")
    worktree=$(jq -r '.worktree // ""' "$state")
  fi

  local branch_exists=false ahead=null dirty=null
  if [[ -n "$branch" ]] && git show-ref --verify --quiet "refs/heads/$branch"; then
    branch_exists=true
    local base_ref="origin/$base"
    git rev-parse --verify --quiet "$base_ref" >/dev/null || base_ref="$base"
    ahead=$(git rev-list --count "$base_ref..$branch" 2>/dev/null || echo null)
  fi
  if [[ -n "$worktree" && -d "$worktree" ]]; then
    dirty=$( [[ -n "$(git -C "$worktree" status --porcelain)" ]] && echo true || echo false )
  fi

  # PR facts are read even in local-only mode so a human-opened PR is noticed.
  local pr=null checks="" unresolved=null
  if [[ -n "$branch" ]] && have_gh; then
    pr=$(gh pr list --head "$branch" --state all --limit 1 \
      --json number,state,url,isDraft,reviewDecision,latestReviews,mergeable,labels \
      --jq '.[0] // null | if . then
        # reviewDecision is empty when the repo requires no reviews; fall back to latest reviews.
        .approved = (.reviewDecision == "APPROVED" or (.reviewDecision == "" and any(.latestReviews[]; .state == "APPROVED")))
        | .held = any(.labels[]; .name == "dont-merge")
        | del(.latestReviews, .labels) else . end' 2>/dev/null || echo null)
    pr=${pr:-null}  # --jq prints nothing for a null result
    if [[ "$pr" != "null" && "$(jq -r .state <<<"$pr")" == "OPEN" ]]; then
      local n; n=$(jq -r .number <<<"$pr")
      # `gh pr checks` exits non-zero on failing/pending checks; the JSON is still valid.
      checks=$(gh pr checks "$n" --json bucket 2>/dev/null | jq -r '
        if length == 0 then "none"
        elif any(.bucket == "fail" or .bucket == "cancel") then "fail"
        elif any(.bucket == "pending") then "pending"
        else "pass" end' || true)
      local nwo; nwo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
      unresolved=$(gh api graphql -F owner="${nwo%/*}" -F name="${nwo#*/}" -F number="$n" -f query='
        query($owner:String!,$name:String!,$number:Int!){
          repository(owner:$owner,name:$name){ pullRequest(number:$number){
            reviewThreads(first:100){ nodes { isResolved } } } } }' \
        --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)] | length' \
        2>/dev/null || echo null)
      unresolved=${unresolved:-null}
    fi
  fi

  # Observed facts win over state.json; state.json only orders the local stages.
  local derived=$stage
  if [[ "$pr" != "null" ]]; then
    case "$(jq -r .state <<<"$pr")" in
      MERGED) derived="done-merged" ;;
      CLOSED) derived="done-closed" ;;
      OPEN)
        if [[ "$publish" == "false" ]]; then
          derived="pr-opened-externally"
        elif [[ "$(jq -r .held <<<"$pr")" == "true" ]]; then
          derived="held"
        elif [[ "$(jq -r .isDraft <<<"$pr")" == "false" && "$(jq -r .approved <<<"$pr")" == "true" \
                && "$checks" =~ ^(pass|none)$ \
                && "$unresolved" == "0" && "$(jq -r .mergeable <<<"$pr")" != "CONFLICTING" ]]; then
          derived="ready-to-merge"
        else
          derived="shepherd"
        fi ;;
    esac
  elif [[ "$stage" =~ ^(build|validate|publish|shepherd|handoff)$ && "$branch_exists" == "false" ]]; then
    derived="inconsistent"
  fi

  jq -n \
    --arg id "$id" --arg dir "$dir" --arg recorded "$stage" --arg derived "$derived" \
    --arg branch "$branch" --argjson branch_exists "$branch_exists" \
    --argjson ahead "$ahead" --argjson dirty "$dirty" \
    --argjson pr "$pr" --arg checks "$checks" --argjson unresolved "$unresolved" \
    '{id: $id, state_dir: $dir, recorded_stage: $recorded, derived_stage: $derived,
      branch: (if $branch == "" then null else $branch end), branch_exists: $branch_exists,
      commits_ahead: $ahead, worktree_dirty: $dirty,
      pr: $pr, checks: (if $checks == "" then null else $checks end),
      unresolved_threads: $unresolved}'
}

cmd_list() {
  local root; root="$(state_root)/$(repo_key)"
  [[ -d "$root" ]] || { echo "[]"; return; }
  local f
  for f in "$root"/*/state.json; do
    [[ -f "$f" ]] && jq -c '{id, title, group, part, ticket: .ticket.key, stage, awaiting, mode, publish, pr: .pr.url}' "$f"
  done | jq -s .
}

# Runs state.json's `checks` ([{name, command}]) in the worktree. The commands
# live outside the repo, so a branch can't change what it is judged by.
cmd_checks() {
  local id=$1 dir state wt
  dir=$(item_dir "$id"); state="$dir/state.json"
  [[ -f "$state" ]] || die "no state for '$id'"
  wt=$(jq -r '.worktree // ""' "$state")
  [[ -n "$wt" && -d "$wt" ]] || die "worktree for '$id' not found: '$wt'"
  local n; n=$(jq '.checks // [] | length' "$state")
  ((n > 0)) || die "no checks recorded in $state (copy them from plan.md's Commands)"

  local log="$dir/checks.log" out failed=0 i name cmd rc head
  local summary="" failures=""
  head=$(git -C "$wt" rev-parse --short HEAD)
  out=$(mktemp); : > "$log"
  for ((i = 0; i < n; i++)); do
    name=$(jq -r ".checks[$i].name" "$state")
    cmd=$(jq -r ".checks[$i].command" "$state")
    rc=0; (cd "$wt" && bash -c "$cmd") > "$out" 2>&1 || rc=$?
    { echo "### $name (exit $rc): $cmd"; cat "$out"; echo; } >> "$log"
    if ((rc == 0)); then
      summary+="- $name: pass"$'\n'
    else
      failed=$((failed + 1))
      summary+="- $name: FAIL (exit $rc)"$'\n'
      failures+=$'\n'"### $name (exit $rc, last 40 lines)"$'\n\n'"\`\`\`"$'\n'"\$ $cmd"$'\n'"$(tail -n 40 "$out")"$'\n'"\`\`\`"$'\n'
    fi
  done
  rm -f "$out"
  [[ -z "$(git -C "$wt" status --porcelain)" ]] \
    || summary+="- worktree has uncommitted changes after the checks"$'\n'

  {
    if ((failed)); then echo "CHECKS: FAIL ($failed of $n)"; else echo "CHECKS: PASS"; fi
    echo; echo "# Checks: $id @ $head"; echo
    echo "## Summary"; echo; printf '%s' "$summary"
    [[ -z "$failures" ]] || { echo; echo "## Failures"; printf '%s' "$failures"; }
    echo; echo "Full output: checks.log"
  } > "$dir/checks.md"
  head -1 "$dir/checks.md"
  ((failed == 0))
}

# A group's items across every repo, split into published PRs (ordered by
# part) and items with no PR yet.
cmd_prs() {
  local group=$1 root
  root=$(state_root)
  shopt -s nullglob
  local files=("$root"/*/*/state.json)
  ((${#files[@]})) || die "no items found under $root"
  jq -s --arg g "$group" '
    [.[] | select(.group == $g)] | sort_by(.part // 0, .id) as $items
    | if ($items | length) == 0 then error("no items in group \($g)") else . end
    | {group: $g,
       ticket: ($items | map(.ticket) | map(select(. != null)) | first),
       prs: [$items[] | select(.pr.url != null)
             | {url: .pr.url, summary: (.summary // .title), title, draft: (.pr.draft // null)}],
       pending: [$items[] | select(.pr.url == null) | {id, summary: (.summary // .title)}]}
  ' "${files[@]}"
}

case "${1:-}" in
  prs)    [[ -n "${2:-}" ]] || die "usage: coordinate.sh prs <group>"; cmd_prs "$2"; exit ;;
esac

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"

case "${1:-}" in
  dir)    check_id "${2:-}"; item_dir "$2" ;;
  status) check_id "${2:-}"; cmd_status "$2" ;;
  list)   cmd_list ;;
  checks) check_id "${2:-}"; cmd_checks "$2" ;;
  *)      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
