#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tag_prefix="${TAG_PREFIX:-v}"
bump="${BUMP:-patch}"
version="${VERSION:-}"
push="${PUSH:-0}"
dry_run="${DRY_RUN:-0}"
allow_dirty="${ALLOW_DIRTY:-0}"

if [ "$allow_dirty" != "1" ] && [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is not clean. Commit or stash changes before releasing." >&2
  exit 1
fi

if [ -n "$version" ]; then
  version="${version#${tag_prefix}}"
else
  latest_tag="$(git tag --list "${tag_prefix}[0-9]*.[0-9]*.[0-9]*" --sort=-v:refname | head -n 1)"
  latest_version="${latest_tag#${tag_prefix}}"

  if [ -z "$latest_tag" ]; then
    latest_version="0.0.0"
  fi

  IFS=. read -r major minor patch <<< "$latest_version"

  case "$bump" in
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    patch)
      patch=$((patch + 1))
      ;;
    *)
      echo "Unsupported BUMP='${bump}'. Use major, minor, or patch." >&2
      exit 1
      ;;
  esac

  version="${major}.${minor}.${patch}"
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must be a semantic version like 0.1.0." >&2
  exit 1
fi

tag="${tag_prefix}${version}"

if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
  echo "Tag ${tag} already exists." >&2
  exit 1
fi

echo "Preparing release ${tag}"

if [ "$dry_run" = "1" ]; then
  echo "DRY_RUN=1: would create annotated tag ${tag}."
else
  git tag -a "$tag" -m "Release ${tag}"
  echo "Created tag ${tag}."
fi

if [ "$push" = "1" ]; then
  if [ "$dry_run" = "1" ]; then
    echo "DRY_RUN=1: would push ${tag} to origin."
  else
    git push origin "$tag"
  fi
else
  echo "Push the tag to trigger GitHub Actions release:"
  echo "  git push origin ${tag}"
fi
