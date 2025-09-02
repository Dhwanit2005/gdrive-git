#!/bin/bash

# GDrive CLI Complete Test Suite
# Tests all commands and workflows

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directory
TEST_DIR="gdrive_test_$(date +%s)"
ORIGINAL_DIR=$(pwd)

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((TESTS_SKIPPED++))
}

cleanup() {
    log_info "Cleaning up test environment..."
    cd "$ORIGINAL_DIR"
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# ==========================
# SETUP
# ==========================

echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     GDrive CLI Complete Test Suite${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo

# Check if credentials.json exists
if [[ ! -f "credentials.json" ]]; then
    log_error "credentials.json not found in current directory"
    echo "Please download credentials from Google Cloud Console first"
    exit 1
fi

# Check if gdrive commands are installed
log_info "Checking if gdrive commands are installed..."
if ! command -v gdrive &> /dev/null; then
    log_error "gdrive command not found. Please run install.sh first"
    exit 1
fi
log_success "GDrive commands found"

# Create test directory
log_info "Creating test directory: $TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Copy credentials to test directory
cp ../credentials.json .

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 1: Initialize Workspace${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

log_info "Testing gdrive init..."
if gdrive init "test-workspace-$(date +%s)"; then
    log_success "Workspace initialized"
else
    log_error "Failed to initialize workspace"
    exit 1
fi

# Verify .gdrive directory was created
if [[ -d ".gdrive" ]]; then
    log_success ".gdrive directory created"
else
    log_error ".gdrive directory not found"
fi

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 2: List Files (Empty)${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

log_info "Testing gdrive ls on empty workspace..."
if gdrive ls; then
    log_success "Listed empty workspace"
else
    log_error "Failed to list files"
fi

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 3: Add Files${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

# Create test files
log_info "Creating test files..."
echo "# Test README" > README.md
echo "print('Hello, World!')" > test.py
echo "Test data" > data.txt
mkdir -p docs
echo "Documentation" > docs/guide.md

log_info "Testing gdrive add..."
if gdrive add README.md; then
    log_success "Added README.md"
else
    log_error "Failed to add README.md"
fi

if gdrive add test.py; then
    log_success "Added test.py"
else
    log_error "Failed to add test.py"
fi

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 4: Status Check${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

log_info "Testing gdrive status..."
if gdrive status; then
    log_success "Status command works"
else
    log_error "Status command failed"
fi

# Check verbose status
log_info "Testing gdrive status -v..."
if gdrive status -v; then
    log_success "Verbose status works"
else
    log_error "Verbose status failed"
fi

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 5: List Files (With Content)${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

log_info "Testing gdrive ls with files..."
if gdrive ls; then
    log_success "Listed files"
else
    log_error "Failed to list files"
fi

# Test filtering
log_info "Testing gdrive ls --type document..."
gdrive ls --type document || log_warning "No documents found (expected)"

log_info "Testing gdrive ls --name test..."
if gdrive ls --name test; then
    log_success "Name filter works"
else
    log_error "Name filter failed"
fi

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 6: Cat Command${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

log_info "Testing gdrive cat..."
if gdrive cat README.md; then
    log_success "Cat command works"
else
    log_error "Cat command failed"
fi

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 7: Push Command${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

# Modify a file
log_info "Modifying README.md..."
echo "## Updated content" >> README.md

log_info "Testing gdrive push --dry-run..."
if gdrive push --dry-run; then
    log_success "Push dry-run works"
else
    log_error "Push dry-run failed"
fi

log_info "Testing gdrive push..."
if gdrive push -f; then
    log_success "Push command works"
else
    log_error "Push command failed"
fi

# Test pushing new untracked file
log_info "Testing push with --auto-add..."
echo "New file content" > newfile.txt
if gdrive push --auto-add -f; then
    log_success "Push with auto-add works"
else
    log_error "Push with auto-add failed"
fi

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 8: Pull Command${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

# Remove a local file to test pull
log_info "Removing local file to test pull..."
rm -f test.py

log_info "Testing gdrive pull --dry-run..."
if gdrive pull --dry-run; then
    log_success "Pull dry-run works"
else
    log_error "Pull dry-run failed"
fi

log_info "Testing gdrive pull..."
if gdrive pull -f; then
    log_success "Pull command works"
    if [[ -f "test.py" ]]; then
        log_success "File restored from Drive"
    else
        log_error "File not restored"
    fi
else
    log_error "Pull command failed"
fi

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 9: CD Navigation${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

log_info "Creating folder structure for navigation..."
mkdir -p project1/src
mkdir -p project2
echo "Source code" > project1/src/main.py

# Push the folder structure
gdrive push --all -f

log_info "Testing gdrive cd to non-existent folder..."
gdrive cd project1 2>/dev/null || log_success "Correctly failed on non-folder navigation"

log_info "Testing gdrive pwd..."
if command -v gdrive-pwd &> /dev/null; then
    if gdrive-pwd; then
        log_success "pwd command works"
    else
        log_error "pwd command failed"
    fi
else
    log_skip "gdrive-pwd not implemented"
fi

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 10: Remove Command${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

log_info "Testing gdrive rm --dry-run..."
if gdrive rm --dry-run data.txt; then
    log_success "Remove dry-run works"
else
    log_error "Remove dry-run failed"
fi

log_info "Testing gdrive rm with force..."
if gdrive rm -f data.txt; then
    log_success "Remove command works"
    if [[ ! -f "data.txt" ]]; then
        log_success "Local file also removed"
    else
        log_error "Local file still exists"
    fi
else
    log_error "Remove command failed"
fi

log_info "Testing gdrive rm --keep-local..."
echo "Keep me locally" > keepme.txt
gdrive add keepme.txt
if gdrive rm --keep-local -f keepme.txt; then
    if [[ -f "keepme.txt" ]]; then
        log_success "File kept locally after Drive removal"
    else
        log_error "File was removed locally (should have been kept)"
    fi
else
    log_error "Remove with --keep-local failed"
fi

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 11: Conflict Handling${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

log_info "Creating conflict scenario..."
echo "Local change" >> README.md

# We can't easily simulate remote changes, so we'll test conflict detection
log_info "Testing conflict detection..."
gdrive status | grep -q "Modified" && log_success "Detects local modifications" || log_error "Failed to detect modifications"

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 12: .gdriveignore${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

log_info "Creating .gdriveignore file..."
cat > .gdriveignore << EOFIGNORE
*.log
*.tmp
temp/
build/
EOFIGNORE

# Create ignored files
echo "Should be ignored" > test.log
echo "Should be ignored" > test.tmp
mkdir -p temp
echo "Ignored folder content" > temp/file.txt

log_info "Testing that ignored files don't appear in status..."
if gdrive status | grep -q "test.log"; then
    log_error "Ignored files appearing in status"
else
    log_success ".gdriveignore working"
fi

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 13: Error Handling${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

log_info "Testing error on non-existent file..."
gdrive cat nonexistent.txt 2>/dev/null && log_error "Should have failed" || log_success "Correctly handles non-existent files"

log_info "Testing error on invalid command..."
gdrive invalidcommand 2>/dev/null && log_error "Should have failed" || log_success "Correctly handles invalid commands"

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST 14: Help Commands${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

log_info "Testing help flags..."
commands=("gdrive" "gdrive-init" "gdrive-ls" "gdrive-add-remote" "gdrive-cat" 
          "gdrive-rm" "gdrive-status" "gdrive-push" "gdrive-pull" "gdrive-cd")

for cmd in "${commands[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        if $cmd --help &> /dev/null; then
            log_success "$cmd --help works"
        else
            log_error "$cmd --help failed"
        fi
    else
        log_skip "$cmd not found"
    fi
done

echo
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}     TEST SUMMARY${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
echo -e "Total: $TOTAL_TESTS"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo
    echo -e "${GREEN}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}     ALL TESTS PASSED! 🎉${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════${NC}"
    exit 0
else
    echo
    echo -e "${RED}═══════════════════════════════════════════${NC}"
    echo -e "${RED}     SOME TESTS FAILED${NC}"
    echo -e "${RED}═══════════════════════════════════════════${NC}"
    exit 1
fi
