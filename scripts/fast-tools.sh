#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Timestamp (YYYYMMDD-HHMMSS)
TS=$(date +"%Y%m%d-%H%M%S")

# Debug function
debug_info() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Error function
error_exit() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Warning function
warning_info() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Success function
success_info() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error_exit "Directory ini bukan Git repository!"
    fi
}

# Check git status
check_git_status() {
    debug_info "Memeriksa status Git..."
    if git status --porcelain | grep -q .; then
        warning_info "Ada perubahan yang belum di-commit:"
        git status --short
        return 0
    else
        warning_info "Tidak ada perubahan yang belum di-commit."
        return 1
    fi
}

# Show current branch
show_current_branch() {
    CURRENT_BRANCH=$(git branch --show-current)
    debug_info "Branch saat ini: $CURRENT_BRANCH"
}

echo -e "${BLUE}[*] Git Branch Creator - Enhanced Version${NC}"
echo "=========================================="

# Check git repository first
check_git_repo
show_current_branch

# Verbose mode option
read -p "Enable verbose mode? (y/N): " VERBOSE
if [[ $VERBOSE =~ ^[Yy]$ ]]; then
    set -x  # Enable debug mode
    debug_info "Verbose mode enabled"
fi

echo -e "${BLUE}[*] Pilih tipe branch:${NC}"
echo "1) feature"
echo "2) update" 
echo "3) backup"
echo "4) hotfix"
echo "5) custom"
read -p "Masukkan angka (default 1): " opt

case "$opt" in
  1|"") TYPE="feature" ;;
  2) TYPE="update" ;;
  3) TYPE="backup" ;;
  4) TYPE="hotfix" ;;
  5) read -p "Nama custom: " TYPE ;;
  *) error_exit "Pilihan tidak valid." ;;
esac

# Ask for description
read -p "Deskripsi branch (opsional): " DESC
if [ -n "$DESC" ]; then
    BRANCH="${TYPE}/$(echo "$DESC" | tr ' ' '-')-${TS}"
    COMMIT_MSG="${TYPE}: ${DESC} - ${TS}"
else
    BRANCH="${TYPE}/auto-${TS}"
    COMMIT_MSG="${TYPE} + ${TS}"
fi

debug_info "Nama branch: $BRANCH"
debug_info "Pesan commit: $COMMIT_MSG"

# Check for changes before proceeding
if ! check_git_status; then
    read -p "Tidak ada perubahan yang akan di-commit. Lanjutkan membuat branch? (y/N): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        warning_info "Operasi dibatalkan."
        exit 0
    fi
fi

echo -e "${BLUE}[*] Membuat branch baru: $BRANCH${NC}"
if ! git checkout -b "$BRANCH"; then
    error_exit "Gagal membuat branch $BRANCH"
fi

# Add files with confirmation
if check_git_status; then
    read -p "Add semua file dan commit? (Y/n): " DO_COMMIT
    if [[ ! $DO_COMMIT =~ ^[Nn]$ ]]; then
        echo -e "${BLUE}[*] Menambahkan file...${NC}"
        git add .
        
        # Signed commit option
        read -p "Gunakan signed commit? (y/N): " SIGNED
        if [[ $SIGNED =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}[*] Melakukan signed commit...${NC}"
            if ! git commit -S -m "$COMMIT_MSG"; then
                warning_info "Gagal signed commit, mencoba commit biasa..."
                git commit -m "$COMMIT_MSG"
            fi
        else
            echo -e "${BLUE}[*] Melakukan commit...${NC}"
            git commit -m "$COMMIT_MSG"
        fi
    fi
fi

# Remote operations
echo -e "${BLUE}[*] Memeriksa remote repository...${NC}"
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [ -z "$REMOTE_URL" ]; then
    warning_info "Tidak ada remote 'origin' yang dikonfigurasi"
    read -p "Tambahkan remote origin? (y/N): " ADD_REMOTE
    if [[ $ADD_REMOTE =~ ^[Yy]$ ]]; then
        read -p "URL remote repository: " REMOTE_URL
        git remote add origin "$REMOTE_URL"
    fi
else
    debug_info "Remote URL: $REMOTE_URL"
fi

# Push to remote
if [ -n "$REMOTE_URL" ]; then
    read -p "Push ke remote origin? (Y/n): " DO_PUSH
    if [[ ! $DO_PUSH =~ ^[Nn]$ ]]; then
        # Handle HTTPS credentials
        if echo "$REMOTE_URL" | grep -q "^https://"; then
            read -p "Remote menggunakan HTTPS. Gunakan credential helper? (Y/n): " USE_CREDENTIAL
            if [[ ! $USE_CREDENTIAL =~ ^[Nn]$ ]]; then
                debug_info "Menggunakan credential helper..."
            else
                read -p "Git username: " GUSER
                read -s -p "Git password/token: " GPASS
                echo
                git remote set-url origin "https://${GUSER}:${GPASS}@$(echo $REMOTE_URL | sed 's|https://||')"
            fi
        fi
        
        echo -e "${BLUE}[*] Push ke origin...${NC}"
        if git push -u origin "$BRANCH"; then
            success_info "Branch $BRANCH berhasil dibuat dan di-push ke remote"
        else
            warning_info "Gagal push ke remote, branch hanya tersimpan secara lokal"
        fi
    fi
fi

# Final status
echo "=========================================="
success_info "Operasi selesai!"
debug_info "Branch aktif: $(git branch --show-current)"
echo -e "${GREEN}✓ Branch: $BRANCH${NC}"
echo -e "${GREEN}✓ Commit: $COMMIT_MSG${NC}"

# Show recent commits
echo -e "${BLUE}[*] 3 commit terakhir:${NC}"
git log --oneline -3
