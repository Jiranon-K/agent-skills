#!/usr/bin/env bash
# Install this repo into a Mac's Claude Code setup. bash 3.2 compatible.
#
# Generic skills are symlinked, so `git pull` updates them. Everything that
# holds your own setup (claude/, loop/, scheduled/, skills/loop/) is a template:
# it is copied only when missing and never overwritten, so fill in its
# placeholders after the first install.
#
# Usage:
#   ./scripts/install.sh --dry-run   # show what would change
#   ./scripts/install.sh             # install; skip anything already in place
#   ./scripts/install.sh --force     # replace existing generic skills (moved to ~/.claude/backups/)
set -eu
cd "$(dirname "$0")/.."
REPO="$(pwd)"
BACKUP="$HOME/.claude/backups/agent-skills-$(date +%Y%m%d-%H%M%S)"

dry=0
force=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=1 ;;
    --force)   force=1 ;;
    -h|--help) sed -n 2,12p "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

link() {
  local src="$REPO/$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "ok      $dest"
    return
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$force" -eq 0 ]; then
      echo "skip    $dest (exists; use --force)"
      return
    fi
    echo "replace $dest"
    # Outside ~/.claude/skills: a backup left there would load as a duplicate skill.
    if [ "$dry" -eq 0 ]; then
      mkdir -p "$BACKUP$(dirname "$dest")"
      mv "$dest" "$BACKUP$dest"
    fi
  else
    echo "link    $dest"
  fi
  [ "$dry" -eq 1 ] && return
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
}

copy_template() {
  local src="$REPO/$1" dest="$2"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    echo "keep    $dest"
    return
  fi
  echo "copy    $dest (template: fill in placeholders)"
  [ "$dry" -eq 1 ] && return
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
}

for dir in skills/*/*/; do
  [ -f "$dir/SKILL.md" ] || continue
  name="$(basename "$dir")"
  case "$dir" in
    skills/loop/*) copy_template "${dir%/}" "$HOME/.claude/skills/$name" ;;
    *)             link "${dir%/}" "$HOME/.claude/skills/$name" ;;
  esac
done

for f in CLAUDE.md AGENTS.md statusline.sh; do
  copy_template "claude/$f" "$HOME/.claude/$f"
done
for f in claude/agents/*/*.md; do
  copy_template "$f" "$HOME/.claude/agents/$(basename "$f")"
done
for f in claude/rules/*.md; do
  copy_template "$f" "$HOME/.claude/rules/$(basename "$f")"
done

for dir in scheduled/*/; do
  copy_template "${dir%/}" "$HOME/.claude/scheduled-tasks/$(basename "$dir")"
done

link loop/bin/loop-run.sh "$HOME/loop/bin/loop-run.sh"
copy_template loop/config.example.sh "$HOME/loop/config.sh"
copy_template loop/repos.example "$HOME/loop/repos"
copy_template loop/workspace.example.md "$HOME/loop/workspace.md"
# loop-state holds no placeholders and is the protocol the runner and loop skills share: keep it current.
link loop/bin/loop-state "$HOME/loop/bin/loop-state"
# loop-heavy serializes heavy commands across parallel Workers.
link loop/bin/loop-heavy "$HOME/loop/bin/loop-heavy"
# loop-push is the only way a Worker pushes: current feature branch, no refspec, no force.
link loop/bin/loop-push "$HOME/loop/bin/loop-push"
link loop/bin/loop-mr "$HOME/loop/bin/loop-mr"
link loop/bin/loop-merge "$HOME/loop/bin/loop-merge"
link loop/bin/loop-upload "$HOME/loop/bin/loop-upload"
link loop/bin/loop-preview "$HOME/loop/bin/loop-preview"
# loop-next: a Worker starts the next run when its task ends.
link loop/bin/loop-next "$HOME/loop/bin/loop-next"
link loop/bin/loop-spec "$HOME/loop/bin/loop-spec"
link loop/bin/loop-ask "$HOME/loop/bin/loop-ask"
link loop/bin/loop-clean "$HOME/loop/bin/loop-clean"
link loop/bin/loop-orca "$HOME/loop/bin/loop-orca"

# SessionStart hook and loop-run.sh call it; it reads each repo's own .worktreelinks.
link scripts/wt-setup "$HOME/.claude/hooks/wt-setup"
# SessionStart hook: removes worktrees whose branch was merged (never main/master/staging/develop).
link scripts/wt-prune "$HOME/.claude/hooks/wt-prune"


[ "$dry" -eq 1 ] && echo "(dry run: nothing changed)"
exit 0
