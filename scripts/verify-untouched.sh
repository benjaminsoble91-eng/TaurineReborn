#!/bin/sh
# Taurine Reborn: proves the exploit / kernel / post-exploit code is byte-identical
# to upstream Taurine (Odyssey-Team/Taurine @ b4824a0). Run from the repo root.
set -e
UPSTREAM=b4824a0
PROTECTED="Taurine/exploit Taurine/post-exploit Taurine/electra-stub.swift Taurine/resources \
kern-rw ctbypass amfidebilitate external test-kernrw Taurine/Taurine-Bridging-Header.h \
Taurine/app/ExploitManager"

if ! git cat-file -e "$UPSTREAM^{commit}" 2>/dev/null; then
  echo "Fetching upstream Taurine for comparison..."
  git fetch -q https://github.com/Odyssey-Team/Taurine.git main
fi

if git diff --quiet "$UPSTREAM" -- $PROTECTED; then
  echo "PASS: $(git ls-files $PROTECTED | wc -l | tr -d ' ') protected files are identical to upstream."
else
  echo "FAIL: protected files differ from upstream:"
  git diff --stat "$UPSTREAM" -- $PROTECTED
  exit 1
fi

# The exploit dispatch inside ViewController.jailbreak() must also be untouched.
extract() { awk '/var hasKernelRw = false/{f=1} f{print} /fatalError\("Unable to get kernel r\/w"\)/{getline; print; exit}'; }
if git show "$UPSTREAM:Taurine/app/ViewController.swift" | extract | diff -q - "$(extract < Taurine/app/ViewController.swift > /tmp/.reborn_dispatch; echo /tmp/.reborn_dispatch)" >/dev/null; then
  echo "PASS: exploit dispatch block in ViewController.swift is identical to upstream."
else
  echo "FAIL: exploit dispatch block in ViewController.swift was modified."
  exit 1
fi
