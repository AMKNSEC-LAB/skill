#!/bin/bash
# Smart Git Commit Script for git-pushing skill
# Handles staging, commit message generation, and pushing

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
info() { echo -e "${GREEN}→${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; }

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
info "Current branch: $CURRENT_BRANCH"

# Check if there are changes
if git diff --quiet && git diff --cached --quiet; then
    warn "No changes to commit"
    exit 0
fi

# Stage all changes
info "Staging all changes..."
git add .

# Get staged files for commit message analysis
STAGED_FILES=$(git diff --cached --name-only)
DIFF_STAT=$(git diff --cached --stat)

# Pick a random friendly commit message based on changed files
generate_friendly_message() {
    local files="$1"
    local num=$2

    if echo "$files" | grep -q "test"; then
        local msgs=(
            "야 테스트 좀 고쳤어 ㅋㅋ"
            "테스트 코드 건드렸는데 잘 되겠지 뭐"
            "테스트 살짝 손봤음"
        )
    elif echo "$files" | grep -qE "\.(md|txt|rst)$"; then
        local msgs=(
            "문서 조금 다듬었어"
            "README 좀 깔끔하게 만들었음"
            "문서 업뎃했음 ㅎ"
        )
    elif echo "$files" | grep -qE "package\.json|requirements\.txt|Cargo\.toml"; then
        local msgs=(
            "패키지 버전 올렸음"
            "의존성 좀 정리했어"
            "라이브러리 업뎃함"
        )
    elif git diff --cached | grep -qE "^[\+].*(fix|bug)"; then
        local msgs=(
            "버그 잡았다 ㅠㅠ 드디어"
            "이거 왜 이랬나 했더니 고쳤음"
            "버그 하나 처리했어"
        )
    elif echo "$files" | grep -qE "skill|plugin|agent"; then
        local msgs=(
            "skill 이것저것 고쳤어"
            "skill 살짝 개선함 ㄱㄱ"
            "기능 조금 손봤음"
        )
    else
        local msgs=(
            "이것저것 좀 바꿨음 ㅋ"
            "자잘한 거 수정했어"
            "파일 ${num}개 조졌음 ㅎ"
            "변경사항 올림 ㄱ"
        )
    fi

    local idx=$(( RANDOM % ${#msgs[@]} ))
    echo "${msgs[$idx]}"
}

# Generate commit message if not provided
if [ -z "$1" ]; then
    NUM_FILES=$(echo "$STAGED_FILES" | wc -l | xargs)
    COMMIT_MSG=$(generate_friendly_message "$STAGED_FILES" "$NUM_FILES")
    info "Generated commit message: $COMMIT_MSG"
else
    COMMIT_MSG="$1"
    info "Using provided message: $COMMIT_MSG"
fi

# Create commit with Claude Code footer
git commit -m "$(cat <<EOF
${COMMIT_MSG}

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"

COMMIT_HASH=$(git rev-parse --short HEAD)
info "Created commit: $COMMIT_HASH"

# Push to remote
info "Pushing to origin/$CURRENT_BRANCH..."

# Check if branch exists on remote
if git ls-remote --exit-code --heads origin "$CURRENT_BRANCH" >/dev/null 2>&1; then
    # Branch exists, just push
    if git push; then
        info "Successfully pushed to origin/$CURRENT_BRANCH"
        echo "$DIFF_STAT"
    else
        error "Push failed"
        exit 1
    fi
else
    # New branch, push with -u
    if git push -u origin "$CURRENT_BRANCH"; then
        info "Successfully pushed new branch to origin/$CURRENT_BRANCH"
        echo "$DIFF_STAT"

        # Check if it's GitHub and show PR link
        REMOTE_URL=$(git remote get-url origin)
        if echo "$REMOTE_URL" | grep -q "github.com"; then
            REPO=$(echo "$REMOTE_URL" | sed -E 's/.*github\.com[:/](.*)\.git/\1/')
            warn "Create PR: https://github.com/$REPO/pull/new/$CURRENT_BRANCH"
        fi
    else
        error "Push failed"
        exit 1
    fi
fi

exit 0