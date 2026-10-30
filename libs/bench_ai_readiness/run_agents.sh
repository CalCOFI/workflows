#!/usr/bin/env bash
# run the AI-readiness pilot: each question x condition x repeat as one headless Claude Code session
#   usage: libs/bench_ai_readiness/run_agents.sh <run_id> [conditions] [reps] [jobs] [model] [effort]
#   e.g.   libs/bench_ai_readiness/run_agents.sh 2026-10-30_opus-5-5_high "closed raw release" 3 6 claude-opus-5-5 high
# name the run_id <date>_<model>_<effort>; config.json in the run folder records both
# conditions:
#   closed   no tools; the model answers from training alone
#   raw      shell + web, limited to the original providers' public portals (ERDDAP, CalCOFI.org,
#            EDI, NCEI, ...); the integrated release and calcofi.io are blocked
#   release  shell, no network; the release as a local DuckDB (build_release_db.sh)
# each session runs in Claude Code's OS sandbox (writes only to its own folder, reads denied on the
# repos, the release copy for `raw`, and ~/.claude), with no CLAUDE.md, memory, skills or MCP.
# transcripts (stream-json) land in $runs_dir/<run_id>/<cond>/<qid>_r<rep>/transcript.jsonl;
# BENCH_QIDS="R1|A4" limits the run to those questions. collect_runs.R summarizes them into data/bench_ai_readiness/.
set -euo pipefail
run_id="${1:?run_id}"; conds="${2:-closed raw release}"; reps="${3:-1}"; jobs="${4:-6}"
model="${5:-claude-sonnet-5-5}"; effort="${6:-default}"
here="$(cd "$(dirname "$0")" && pwd)"
release_dir="${BENCH_RELEASE_DIR:-$HOME/_big/bench_ai_release}"
runs_dir="${BENCH_RUNS_DIR:-$HOME/_big/bench_ai_runs}"
out="$runs_dir/$run_id"; mkdir -p "$out"
printf '{"model":"%s","effort":"%s","claude_version":"%s"}\n' "$model" "$effort" "$(claude --version | head -1)" > "$out/config.json"
effort_arg=""; [ "$effort" != default ] && effort_arg="--effort $effort"

# questions as one json line each: {id, text}
Rscript -e 'q <- yaml::read_yaml(commandArgs(TRUE)[1])$questions
  for (x in q) cat(jsonlite::toJSON(list(id = x$id, text = x$text), auto_unbox = TRUE), "\n")' \
  "$here/questions.yml" > "$out/questions.jsonl"

raw_domains='["coastwatch.pfeg.noaa.gov","oceanview.pfeg.noaa.gov","upwell.pfeg.noaa.gov","calcofi.org","www.calcofi.org","new.data.calcofi.org","portal.edirepository.org","pasta.lternet.edu","cce.lternet.edu","oceaninformatics.ucsd.edu","www.ncei.noaa.gov","ncei.noaa.gov","www.nodc.noaa.gov","www.fisheries.noaa.gov","swfsc.noaa.gov","www.bco-dmo.org","erddap.bco-dmo.org","erddap.sccoos.org","sccoos.org","spraydata.ucsd.edu","www.marinespecies.org","api.gbif.org","obis.org","api.obis.org","ccelter.ucsd.edu","library.ucsd.edu","calcofi.com","www.calcofi.com","doi.org","dx.doi.org","api.datacite.org","cn.dataone.org","search.dataone.org","erddap.cencoos.org","www.cencoos.org"]'
blocked_fetch='["WebFetch(domain:calcofi.io)","WebFetch(domain:storage.calcofi.io)","WebFetch(domain:storage.googleapis.com)","WebFetch(domain:github.com)","WebFetch(domain:raw.githubusercontent.com)","WebFetch(domain:zenodo.org)"]'

settings_for() { # $1 = condition
  # each condition is also denied the other conditions' run folders
  local other=release; [ "$1" = release ] && other=raw
  local deny_read='"~/Github","~/.claude/CLAUDE.md","~/.claude/skills","~/.claude/projects/-Users-bbest-Github-CalCOFI-workflows","~/Library","~/_big/calcofi","'"$out/$other"'"'
  case "$1" in
    raw)     echo '{"sandbox":{"enabled":true,"autoAllowBashIfSandboxed":true,"allowUnsandboxedCommands":false,
               "network":{"allowedDomains":'"$raw_domains"'},
               "filesystem":{"denyRead":['"$deny_read"',"'"$release_dir"'"]}},
               "permissions":{"allow":["Bash","Read","Write","Edit","Glob","Grep","WebFetch","WebSearch"],"deny":'"$blocked_fetch"'}}' ;;
    release) echo '{"sandbox":{"enabled":true,"autoAllowBashIfSandboxed":true,"allowUnsandboxedCommands":false,
               "network":{"allowedDomains":[]},"filesystem":{"denyRead":['"$deny_read"']}},
               "permissions":{"allow":["Bash","Read","Write","Edit","Glob","Grep"]}}' ;;
    closed)  echo '{}' ;;
  esac
}

system_for() { # $1 = condition
  local common="You are answering one quantitative question about California Current ocean observations. Work carefully and state the definitions you used. End your reply with one line exactly of the form 'FINAL ANSWER: <value>' giving a bare number (no units) or, for a name, the name; if the available data cannot answer the question, end with 'FINAL ANSWER: NOT AVAILABLE'."
  case "$1" in
    closed)  echo "$common You have no tools and no data access; answer from your own knowledge with your best estimate, or NOT AVAILABLE." ;;
    raw)     echo "$common Find and download the data yourself from the original data providers' public sources (for example NOAA ERDDAP at coastwatch.pfeg.noaa.gov, CalCOFI.org data pages, the Environmental Data Initiative portal, NCEI). Do not use calcofi.io or any integrated CalCOFI database release. Work only inside the current directory. Tools on this machine include curl, duckdb, python3 (standard library only) and R." ;;
    release) echo "$common The data are in the local DuckDB database described in README.md in the current directory. There is no network access. Work only inside the current directory. Tools on this machine include duckdb, python3 (standard library only) and R." ;;
  esac
}

one() { # $1 cond, $2 qid, $3 rep
  local cond="$1" qid="$2" rep="$3"
  local d="$out/$cond/${qid}_r$rep"; mkdir -p "$d"
  [ -s "$d/result.json" ] && return 0   # an empty result.json is a killed session: rerun it
  local text; text="$(jq -r --arg id "$qid" 'select(.id==$id) | .text' "$out/questions.jsonl")"
  local tools="" secs=240 budget=0.5
  case "$cond" in
    raw)     tools="Bash,Read,Write,Edit,Glob,Grep,WebFetch,WebSearch"; secs=2400; budget=6 ;;
    release) tools="Bash,Read,Write,Edit,Glob,Grep"; secs=1200; budget=3
             ln -sf "$release_dir/release.duckdb" "$d/release.duckdb"; cp "$here/release_README.md" "$d/README.md" ;;
  esac
  settings_for "$cond" > "$d/settings.json"
  ( cd "$d" && perl -e 'alarm shift; exec @ARGV' "$secs" \
      claude -p "$text" --model "$model" $effort_arg --setting-sources "" --settings settings.json --strict-mcp-config \
        --tools "$tools" --permission-mode dontAsk --no-session-persistence --max-budget-usd "$budget" \
        --append-system-prompt "$(system_for "$cond")" --output-format stream-json --verbose \
        > transcript.jsonl 2> stderr.txt ) || echo "{\"timeout_or_error\": $?}" > "$d/exit.json"
  grep '"type":"result"' "$d/transcript.jsonl" | tail -1 > "$d/result.json" || true
  echo "$(date +%T) done $cond $qid r$rep"
}
export -f one settings_for system_for
export out here release_dir runs_dir model effort_arg raw_domains blocked_fetch

for cond in $conds; do for rep in $(seq 1 "$reps"); do
  jq -r '.id' "$out/questions.jsonl" | grep -E "^(${BENCH_QIDS:-.*})$" | sed "s/^/$cond /; s/$/ $rep/"
done; done | xargs -P "$jobs" -L 1 bash -c 'one "$0" "$1" "$2"'
echo "all done: $out" && touch "$out/.done"
