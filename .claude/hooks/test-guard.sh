#!/usr/bin/env bash
# Pipe-tests for .claude/hooks/guard.js — run from the repo root.
G=.claude/hooks/guard.js
fails=0
t(){ out=$(printf '%s' "$2" | node "$G"); d=$(printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",x=>s+=x).on("end",()=>{try{console.log(JSON.parse(s).hookSpecificOutput.permissionDecision)}catch(e){console.log("pass")}})'); if [ "$d" = "$1" ]; then r=OK; else r="FAIL(got $d)"; fails=$((fails+1)); fi; printf '%-5s expect=%-5s %s\n' "$r" "$1" "$3"; }
B(){ node -e 'process.stdout.write(JSON.stringify({tool_name:"Bash",cwd:process.argv[2],tool_input:{command:process.argv[1]}}))' "$1" "$PWD"; }
F(){ node -e 'process.stdout.write(JSON.stringify({tool_name:process.argv[1],tool_input:{file_path:process.argv[2]}}))' "$1" "$2"; }
t pass "$(B 'ls -la')" "ls"
t pass "$(B 'npx supabase migration list --remote')" "migration list --remote"
t pass "$(B 'npx supabase db push --remote --dry-run')" "db push --dry-run"
t ask  "$(B 'npx supabase db push --remote --yes')" "db push --remote"
t ask  "$(B 'npx supabase migration repair --remote 2026')" "migration repair --remote"
t deny "$(B 'npx supabase db reset --remote')" "db reset --remote"
t pass "$(B 'npx supabase db reset')" "local db reset"
t deny "$(B 'git push origin main')" "push origin main"
t deny "$(B 'git push origin HEAD:main')" "push HEAD:main"
t deny "$(B 'git push --force origin feature/x')" "force push"
t pass "$(B 'git push -u origin chore/hooks-guardrails')" "push branch"
t deny "$(B 'git commit --no-verify -m x')" "--no-verify"
t deny "$(B 'cat .env')" "cat .env"
t deny "$(B 'cp .env.local /tmp/x')" "cp .env.local"
t pass "$(B 'cat .env.example')" "cat .env.example"
t pass "$(B 'git commit -m "docs: block .env access"')" "commit msg mentions .env (false positive)"
t pass "$(B 'git commit -q -m "line1
deny .env access;
more"')" "multi-line commit msg mentions .env"
t deny "$(B 'git commit -m "x" && cat .env')" "commit msg + real .env access"
t deny "$(F Read 'D:\Projects\parking\.env.local')" "Read .env.local"
t pass "$(F Write 'D:\Projects\parking\.env.example')" "Write .env.example"
t pass "$(B 'git commit -m "docs: deny --no-verify and git push origin main"')" "commit msg mentions blocked commands"
t deny "$(B 'git commit -m "ok" --no-verify')" "real --no-verify after a message"
echo "failures: $fails"
