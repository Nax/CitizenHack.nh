#!/usr/bin/env bash

die() {
    exit 1
}

if ! git config remote.upstream.url >/dev/null; then
    git remote add upstream "https://github.com/NetHack/NetHack" || die
fi

# Get the upstream commits
git fetch upstream --depth=50 || die
commit="$(git rev-parse --short upstream/NetHack-3.7)"

# Single commit nethack (sorry for the history but it's just too big)
git checkout nethack || die
git clean -fd || die
git ls-files -z | xargs -0 rm -rf || die
git checkout upstream/NetHack-3.7 -- '*' || die
git add -A || die
git commit -m "NetHack-3.7.0-dev-${commit}" || die
git push origin nethack || die

# Merge
# The last command may fail in case of conflict, it's ok
git checkout develop || die
git merge --no-ff nethack
