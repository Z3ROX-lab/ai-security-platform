# Git Guide - Best Practices

> This guide covers all Git commands used in this project, from repository creation to daily workflow.

---

## 1. Initial Setup

### 1.1 Install Git (Ubuntu/WSL2)
```bash
sudo apt update
sudo apt install -y git
```

### 1.2 Configure Identity
```bash
# Required — used for every commit
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Verify configuration
git config --list
```

### 1.3 Configure Default Editor
```bash
# Use VS Code (recommended)
git config --global core.editor "code --wait"

# Or nano (simple)
git config --global core.editor "nano"

# Or vim
git config --global core.editor "vim"
```

---

## 2. Create a GitHub Repository

### 2.1 On github.com

1. Login to https://github.com
2. Click **"+"** (top right) → **"New repository"**
3. Configure:
   - **Repository name**: `ai-security-platform`
   - **Description**: (optional)
   - **Visibility**: Private or Public
   - **Initialize**: DO NOT check any boxes
4. Click **"Create repository"**

### 2.2 GitHub Authentication

GitHub no longer accepts passwords. Two options:

#### Option A: Personal Access Token (PAT)

1. Go to https://github.com/settings/tokens
2. Click **"Generate new token (classic)"**
3. Check `repo` (full repository access)
4. Click **"Generate token"**
5. **Copy the token** (you won't see it again!)

Use this token as password when cloning.

#### Option B: SSH Key (recommended for long term)
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your.email@example.com"

# Press Enter 3 times (accept defaults)

# Display public key
cat ~/.ssh/id_ed25519.pub
```

Then on GitHub:
1. Go to https://github.com/settings/keys
2. Click **"New SSH key"**
3. Paste the key
4. Click **"Add SSH key"**

---

## 3. Clone a Repository

### 3.1 With HTTPS (+ token)
```bash
# Create work directory
mkdir -p ~/work
cd ~/work

# Clone the repo
git clone https://github.com/USERNAME/REPO_NAME.git

# Example
git clone https://github.com/Z3ROX-lab/ai-security-platform.git
```

When prompted:
- **Username**: your GitHub username
- **Password**: your Personal Access Token (NOT your password)

### 3.2 With SSH
```bash
git clone git@github.com:USERNAME/REPO_NAME.git

# Example
git clone git@github.com:Z3ROX-lab/ai-security-platform.git
```

### 3.3 Save Credentials
```bash
# Store credentials permanently
git config --global credential.helper store
```

---

## 4. Basic Commands

### 4.1 Check Repository Status
```bash
# See modified, added, deleted files
git status

# Short version
git status -s
```

**Legend for git status -s**:
- `??` : Untracked file (new)
- `A ` : Added file (staged)
- `M ` : Modified file (staged)
- ` M` : Modified file (not staged)
- `D ` : Deleted file

### 4.2 Add Files
```bash
# Add specific file
git add myfile.txt

# Add multiple files
git add file1.txt file2.txt

# Add all files in current directory
git add .

# Add all modified files (not new ones)
git add -u

# Add everything (new + modified + deleted)
git add -A
```

### 4.3 Commit
```bash
# Commit with inline message
git commit -m "My commit message"

# Commit with multiline message
git commit -m "Short title

Longer description of the change.
- Point 1
- Point 2"

# Add + commit in one command (tracked files only)
git commit -am "Message"
```

### 4.4 Push to GitHub
```bash
# Push current branch
git push

# Push specific branch
git push origin master
git push origin main
git push origin my-branch

# First push of a new branch
git push -u origin my-branch
```

### 4.5 Pull Changes
```bash
# Fetch + merge
git pull

# Fetch without merging (review first)
git fetch
```

---

## 5. View History

### 5.1 Logs
```bash
# Full history
git log

# Condensed history (one line per commit)
git log --oneline

# With branch graph
git log --oneline --graph --all

# Last 5 commits
git log -5

# Commits for a specific file
git log -- myfile.txt
```

### 5.2 View Differences
```bash
# Unstaged differences
git diff

# Staged differences (ready to commit)
git diff --staged

# Differences between two commits
git diff abc123 def456

# Differences for a specific file
git diff myfile.txt
```

---

## 6. Branches

### 6.1 Why Use Branches?
```
main/master ─────────────────────────────────────▶ Stable production
                    │
                    └── feature/phase-02 ─────────▶ Isolated development
                              │
                              └── Merge when ready
```

### 6.2 Branch Commands
```bash
# List local branches
git branch

# List all branches (local + remote)
git branch -a

# Create new branch
git branch my-new-branch

# Create and switch to branch
git checkout -b my-new-branch

# Or with new syntax
git switch -c my-new-branch

# Switch branch
git checkout my-branch
git switch my-branch

# Delete local branch
git branch -d my-branch

# Force delete
git branch -D my-branch
```

### 6.3 Branch Workflow
```bash
# 1. Create feature branch
git checkout -b feature/phase-02

# 2. Work, add, commit
git add .
git commit -m "Phase 2: Add PostgreSQL"

# 3. Push branch to GitHub
git push -u origin feature/phase-02

# 4. When done, switch back to master
git checkout master

# 5. Merge the feature
git merge feature/phase-02

# 6. Push master
git push origin master

# 7. Delete feature branch
git branch -d feature/phase-02
```

---

## 7. Undo Changes

### 7.1 Before Commit
```bash
# Discard changes to a file (unstaged)
git restore myfile.txt

# Remove file from staging (keep changes)
git restore --staged myfile.txt
```

### 7.2 After Commit
```bash
# Modify last commit (message or content)
git commit --amend -m "New message"

# Undo last commit (keep files)
git reset --soft HEAD~1

# Undo last commit (discard files)
git reset --hard HEAD~1
```

⚠️ **Warning**: Never `reset --hard` on pushed commits!

---

## 8. Commit Best Practices

### 8.1 Message Format
```
<type>: <short description>

<optional longer description>
```

**Common types**:

| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation |
| `refactor` | Code refactoring |
| `test` | Add/modify tests |
| `chore` | Maintenance, dependencies |

### 8.2 Good Message Examples
```bash
# ✅ Good messages
git commit -m "feat: Add Keycloak Helm chart configuration"
git commit -m "fix: Correct redirect URI in ArgoCD OIDC config"
git commit -m "docs: Add Git best practices guide"

# ❌ Bad messages
git commit -m "fix"
git commit -m "update"
git commit -m "wip"
```

### 8.3 Golden Rules

1. **Atomic commits**: One commit = one logical change
2. **Clear messages**: Someone should understand without seeing the code
3. **Present tense**: "Add feature" not "Added feature"
4. **No WIP**: Don't push "work in progress" commits

---

## 9. The .gitignore File

### 9.1 Syntax
```gitignore
# Comment
file.txt             # Ignore specific file
*.log                # Ignore all .log files
/build               # Ignore build folder at root
build/               # Ignore all build folders
!important.log       # Exception — don't ignore this file
```

### 9.2 Our .gitignore (AI Security Platform)
```gitignore
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
*.tfvars
!*.tfvars.example

# Secrets
*.pem
*.key
.env

# Kubernetes
kubeconfig

# IDE
.vscode/
.idea/

# OS
.DS_Store
```

---

## 10. VS Code Integration

### 10.1 Why VS Code?

| Benefit | Detail |
|---------|--------|
| **Native WSL2** | Edit files directly in Ubuntu |
| **Built-in Git** | Visual diffs, commits, branches |
| **Extensions** | Kubernetes, Terraform, YAML, Helm |
| **Free** | Microsoft, actively maintained |
| **Industry standard** | 70%+ of developers use it |

### 10.2 Setup

1. **Install VS Code on Windows**: https://code.visualstudio.com/

2. **Install essential extensions**:
   - Remote - WSL
   - GitLens
   - Kubernetes
   - HashiCorp Terraform
   - YAML
   - Markdown Preview Enhanced

3. **Open project from WSL**:
```bash
cd ~/work/ai-security-platform
code .
```

VS Code opens **connected to WSL** — you edit directly in Ubuntu!

### 10.3 VS Code Git Features

| Feature | How to access |
|---------|---------------|
| Source Control | Ctrl+Shift+G |
| View changes | Click file in Source Control |
| Stage file | Click + next to file |
| Commit | Type message + Ctrl+Enter |
| Push/Pull | Click ... menu or status bar |
| View history | GitLens extension |

### 10.4 Useful Shortcuts

| Action | Shortcut |
|--------|----------|
| Open terminal | Ctrl+` |
| Command palette | Ctrl+Shift+P |
| Search files | Ctrl+P |
| Find in files | Ctrl+Shift+F |
| Toggle sidebar | Ctrl+B |
| Split editor | Ctrl+\ |

---

## 11. Commands Used in This Project

### 11.1 Initial Setup
```bash
# Create directory and clone
mkdir -p ~/work
cd ~/work
git clone https://github.com/Z3ROX-lab/ai-security-platform.git
cd ai-security-platform

# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
git config --global credential.helper store
```

### 11.2 Create Project Structure
```bash
# Create directories
mkdir -p docs/adr
mkdir -p docs/phases/phase-01
mkdir -p docs/knowledge-base
mkdir -p phases/phase-01/{terraform,argocd,scripts}
```

### 11.3 Daily Workflow
```bash
# Check status
git status

# Add all files
git add .

# Commit
git commit -m "docs: Add Keycloak deep dive documentation"

# Push
git push origin master
```

---

## 12. Quick Reference

| Action | Command |
|--------|---------|
| Clone | `git clone URL` |
| Status | `git status` |
| Add all | `git add .` |
| Commit | `git commit -m "message"` |
| Push | `git push origin master` |
| Pull | `git pull` |
| New branch | `git checkout -b name` |
| Switch branch | `git checkout name` |
| Merge | `git merge name` |
| History | `git log --oneline` |
| Differences | `git diff` |
| Undo changes | `git restore file` |
| Open in VS Code | `code .` |

---

## 13. References

- [Git Documentation](https://git-scm.com/doc)
- [GitHub Guides](https://guides.github.com/)
- [VS Code Docs](https://code.visualstudio.com/docs)
- [Git Cheat Sheet](https://education.github.com/git-cheat-sheet-education.pdf)
