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

## 4. Check Your Configuration

### 4.1 Verify Remote Configuration
```bash
# See the remote URL (fetch and push)
git remote -v
```

**Example output (HTTPS)**:
```
origin  https://Z3ROX-lab@github.com/Z3ROX-lab/ai-security-platform.git (fetch)
origin  https://Z3ROX-lab@github.com/Z3ROX-lab/ai-security-platform.git (push)
```

**Example output (SSH)**:
```
origin  git@github.com:Z3ROX-lab/ai-security-platform.git (fetch)
origin  git@github.com:Z3ROX-lab/ai-security-platform.git (push)
```

### 4.2 Verify Git Configuration
```bash
# View all Git settings
cat ~/.gitconfig

# Or
git config --list
```

### 4.3 Authentication Methods Comparison

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    HTTPS vs SSH Authentication                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  HTTPS + Personal Access Token (PAT)                                    │
│  ═══════════════════════════════════                                     │
│                                                                          │
│  Remote URL: https://github.com/USER/REPO.git                           │
│              https://USER@github.com/USER/REPO.git                      │
│                                                                          │
│  Authentication:                                                         │
│  • PAT stored in credential manager (Windows)                           │
│  • Or in ~/.git-credentials (Linux)                                     │
│  • Or entered at each push                                              │
│                                                                          │
│  Pros:                                                                   │
│  ✅ Works through firewalls (port 443)                                  │
│  ✅ Easy to setup                                                        │
│  ✅ Works with VS Code out of the box                                   │
│                                                                          │
│  Cons:                                                                   │
│  ⚠️ Token expires (needs renewal)                                       │
│  ⚠️ Token can be leaked if stored insecurely                            │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  SSH Key                                                                 │
│  ═══════                                                                 │
│                                                                          │
│  Remote URL: git@github.com:USER/REPO.git                               │
│                                                                          │
│  Authentication:                                                         │
│  • SSH key pair (~/.ssh/id_ed25519 or id_rsa)                          │
│  • Public key added to GitHub Settings → SSH Keys                       │
│                                                                          │
│  Pros:                                                                   │
│  ✅ More secure (no token to leak)                                      │
│  ✅ Never expires                                                        │
│  ✅ No password prompts ever                                            │
│                                                                          │
│  Cons:                                                                   │
│  ⚠️ May be blocked by corporate firewalls (port 22)                     │
│  ⚠️ Slightly more complex initial setup                                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.4 Switch Between HTTPS and SSH
```bash
# View current remote
git remote -v

# Change to SSH
git remote set-url origin git@github.com:USER/REPO.git

# Change to HTTPS
git remote set-url origin https://github.com/USER/REPO.git
```

---

## 5. Basic Commands

### 5.1 Check Repository Status
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

### 5.2 Add Files
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

### 5.3 Commit
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

### 5.4 Push to GitHub
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

### 5.5 Pull Changes
```bash
# Fetch + merge
git pull

# Fetch without merging (review first)
git fetch
```

---

## 6. View History

### 6.1 Logs
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

### 6.2 View Differences
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

## 7. Branches

### 7.1 Why Use Branches?
```
main/master ─────────────────────────────────────▶ Stable production
                    │
                    └── feature/phase-02 ─────────▶ Isolated development
                              │
                              └── Merge when ready
```

### 7.2 Branch Commands
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

### 7.3 Branch Workflow
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

## 8. Undo Changes

### 8.1 Before Commit
```bash
# Discard changes to a file (unstaged)
git restore myfile.txt

# Remove file from staging (keep changes)
git restore --staged myfile.txt
```

### 8.2 After Commit
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

## 9. Commit Best Practices

### 9.1 Message Format
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

### 9.2 Good Message Examples
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

### 9.3 Golden Rules

1. **Atomic commits**: One commit = one logical change
2. **Clear messages**: Someone should understand without seeing the code
3. **Present tense**: "Add feature" not "Added feature"
4. **No WIP**: Don't push "work in progress" commits

---

## 10. The .gitignore File

### 10.1 Syntax
```gitignore
# Comment
file.txt             # Ignore specific file
*.log                # Ignore all .log files
/build               # Ignore build folder at root
build/               # Ignore all build folders
!important.log       # Exception — don't ignore this file
```

### 10.2 Our .gitignore (AI Security Platform)
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

## 11. VS Code Integration

### 11.1 Why VS Code?

| Benefit | Detail |
|---------|--------|
| **Native WSL2** | Edit files directly in Ubuntu |
| **Built-in Git** | Visual diffs, commits, branches |
| **Extensions** | Kubernetes, Terraform, YAML, Helm |
| **Free** | Microsoft, actively maintained |
| **Industry standard** | 70%+ of developers use it |

### 11.2 Install VS Code

1. **Download and install on Windows**: https://code.visualstudio.com/

2. **Install essential extensions** (in VS Code):
   - **Remote - WSL** (required for WSL2)
   - **GitLens** (enhanced Git features)
   - **Kubernetes**
   - **HashiCorp Terraform**
   - **YAML**
   - **Markdown Preview Enhanced**

3. **Open project from WSL terminal**:
```bash
cd ~/work/ai-security-platform
code .
```

VS Code opens **connected to WSL** — you edit directly in Ubuntu!

### 11.3 VS Code + Git Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    VS CODE + WSL2 + GIT FLOW                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  WINDOWS                           WSL2 (Ubuntu)                        │
│  ═══════                           ══════════════                        │
│                                                                          │
│  ┌──────────────┐                 ┌──────────────────────────────────┐  │
│  │   VS Code    │ ◄─────────────► │  ~/work/ai-security-platform/    │  │
│  │   (GUI)      │   Remote WSL    │                                  │  │
│  │              │   Extension     │  ├── .git/                       │  │
│  │  Source      │                 │  ├── argocd/                     │  │
│  │  Control     │                 │  ├── docs/                       │  │
│  │  Panel       │                 │  └── ...                         │  │
│  └──────────────┘                 └──────────────────────────────────┘  │
│        │                                       │                         │
│        │                                       │                         │
│        │                                       ▼                         │
│        │                          ┌──────────────────────────────────┐  │
│        │                          │  Git (installed in Ubuntu)       │  │
│        │                          │                                  │  │
│        │                          │  ~/.gitconfig                    │  │
│        │                          │  ~/.git-credentials              │  │
│        └─────────────────────────►│                                  │  │
│           Uses Git from WSL       └──────────────────────────────────┘  │
│                                                │                         │
│                                                │ HTTPS or SSH            │
│                                                ▼                         │
│                                   ┌──────────────────────────────────┐  │
│                                   │         GitHub.com               │  │
│                                   └──────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 11.4 Source Control Panel

The Source Control panel (`Ctrl+Shift+G`) is your Git GUI:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    VS CODE SOURCE CONTROL                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  SOURCE CONTROL                                    ↻  ...  ─    │    │
│  ├─────────────────────────────────────────────────────────────────┤    │
│  │                                                                  │    │
│  │  Message (Ctrl+Enter to commit)                                 │    │
│  │  ┌─────────────────────────────────────────────────────────┐   │    │
│  │  │ feat: add Open WebUI deployment                          │   │    │
│  │  └─────────────────────────────────────────────────────────┘   │    │
│  │                                                    [✓ Commit]   │    │
│  │                                                                  │    │
│  │  Changes (3)                                              ▼     │    │
│  │  ┌─────────────────────────────────────────────────────────┐   │    │
│  │  │  M  argocd/applications/ai-apps/open-webui/values.yaml  │ + │    │
│  │  │  A  argocd/applications/ai-apps/open-webui/app.yaml     │ + │    │
│  │  │  M  docs/git-guide.md                                   │ + │    │
│  │  └─────────────────────────────────────────────────────────┘   │    │
│  │                                                                  │    │
│  │  Staged Changes (1)                                       ▼     │    │
│  │  ┌─────────────────────────────────────────────────────────┐   │    │
│  │  │  A  README.md                                           │ - │    │
│  │  └─────────────────────────────────────────────────────────┘   │    │
│  │                                                                  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Legend:                                                                │
│  • M = Modified                                                         │
│  • A = Added (new file)                                                 │
│  • D = Deleted                                                          │
│  • + = Stage this file (git add)                                       │
│  • - = Unstage this file (git restore --staged)                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 11.5 Complete Git Workflow in VS Code

#### Step 1: Open Source Control
- Press `Ctrl+Shift+G`
- Or click the branch icon in the left sidebar

#### Step 2: View Changes
- Click on any file to see the diff
- Red = deleted lines
- Green = added lines

#### Step 3: Stage Files
```
┌─────────────────────────────────────────────────────────────────────────┐
│  Option A: Stage individual files                                        │
│  ─────────────────────────────────                                       │
│  Hover over file → Click [+] button                                     │
│                                                                          │
│  Option B: Stage all files                                              │
│  ─────────────────────────────                                           │
│  Hover over "Changes" header → Click [+] button                         │
│                                                                          │
│  Option C: Keyboard shortcut                                            │
│  ───────────────────────────                                             │
│  Select file → Press Ctrl+Shift+G then S                                │
│                                                                          │
│  Equivalent command: git add <file>                                     │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Step 4: Commit
```
┌─────────────────────────────────────────────────────────────────────────┐
│  1. Type commit message in the text box                                 │
│                                                                          │
│     ┌─────────────────────────────────────────────────────────────┐    │
│     │ feat: add Open WebUI deployment                              │    │
│     └─────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  2. Press Ctrl+Enter                                                    │
│     Or click the [✓ Commit] button                                      │
│                                                                          │
│  Equivalent command: git commit -m "feat: add Open WebUI deployment"   │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Step 5: Push
```
┌─────────────────────────────────────────────────────────────────────────┐
│  Option A: Status bar                                                   │
│  ────────────────────                                                    │
│  Click the sync icon (↑↓) in the bottom status bar                     │
│                                                                          │
│  Option B: Menu                                                         │
│  ───────────                                                             │
│  Click [...] in Source Control → Push                                  │
│                                                                          │
│  Option C: Command Palette                                              │
│  ─────────────────────────                                               │
│  Ctrl+Shift+P → Type "Git: Push" → Enter                               │
│                                                                          │
│  Equivalent command: git push                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

### 11.6 VS Code Git Commands Summary

| Action | VS Code | Terminal Equivalent |
|--------|---------|---------------------|
| Open Source Control | `Ctrl+Shift+G` | - |
| View diff | Click file | `git diff <file>` |
| Stage file | Click `+` | `git add <file>` |
| Stage all | Click `+` on Changes | `git add .` |
| Unstage file | Click `-` | `git restore --staged <file>` |
| Commit | Type message + `Ctrl+Enter` | `git commit -m "msg"` |
| Push | Click sync icon or `...` → Push | `git push` |
| Pull | Click sync icon or `...` → Pull | `git pull` |
| View history | GitLens extension | `git log` |
| Switch branch | Click branch name in status bar | `git checkout <branch>` |
| Create branch | Click branch → Create new branch | `git checkout -b <name>` |

### 11.7 Status Bar Indicators

```
┌─────────────────────────────────────────────────────────────────────────┐
│  VS CODE STATUS BAR (bottom left)                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  ⎇ master  ↑1 ↓0  ⚠ 0  ✗ 0                                      │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│      │         │   │                                                     │
│      │         │   └── Commits to pull (0)                              │
│      │         └── Commits to push (1)                                  │
│      └── Current branch (master)                                        │
│                                                                          │
│  Click on branch name to:                                               │
│  • Switch branches                                                      │
│  • Create new branch                                                    │
│  • View recent branches                                                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 11.8 GitLens Extension Features

GitLens adds powerful Git features:

| Feature | How to Use |
|---------|------------|
| **Blame annotations** | Hover over any line → see who wrote it |
| **File history** | Right-click file → GitLens → File History |
| **Line history** | Click on line → see all changes to that line |
| **Compare branches** | Command Palette → GitLens: Compare |
| **Interactive rebase** | Command Palette → GitLens: Interactive Rebase |

### 11.9 Useful Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open terminal | `Ctrl+`` |
| Command palette | `Ctrl+Shift+P` |
| Search files | `Ctrl+P` |
| Find in files | `Ctrl+Shift+F` |
| Toggle sidebar | `Ctrl+B` |
| Split editor | `Ctrl+\` |
| Source Control | `Ctrl+Shift+G` |
| Toggle Git panel | `Ctrl+Shift+G G` |

---

## 12. Troubleshooting

### 12.1 Authentication Issues

**Problem**: Push fails with "Authentication failed"

```bash
# Check your remote URL
git remote -v

# If using HTTPS, verify credential helper
git config --global credential.helper

# Clear stored credentials and retry
git config --global --unset credential.helper
git config --global credential.helper store
git push  # Will prompt for username/token again
```

**Problem**: SSH key not working

```bash
# Test SSH connection
ssh -T git@github.com

# If it fails, check if key is loaded
ssh-add -l

# Add key to agent
ssh-add ~/.ssh/id_ed25519
```

### 12.2 VS Code Issues

**Problem**: VS Code doesn't see Git changes

```bash
# Reload VS Code window
Ctrl+Shift+P → "Developer: Reload Window"

# Or restart VS Code
```

**Problem**: VS Code uses wrong Git

```bash
# Check which Git VS Code is using
# In VS Code terminal:
which git

# Should be: /usr/bin/git (WSL)
# Not: /mnt/c/Program Files/Git/bin/git (Windows)
```

---

## 13. Commands Used in This Project

### 13.1 Initial Setup
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

### 13.2 Create Project Structure
```bash
# Create directories
mkdir -p docs/adr
mkdir -p docs/phases/phase-01
mkdir -p docs/knowledge-base
mkdir -p phases/phase-01/{terraform,argocd,scripts}
```

### 13.3 Daily Workflow (Terminal)
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

### 13.4 Daily Workflow (VS Code)
```
1. Make changes to files
2. Ctrl+Shift+G (open Source Control)
3. Review changes (click files to see diff)
4. Click [+] to stage files
5. Type commit message
6. Ctrl+Enter to commit
7. Click sync icon to push
```

---

## 14. Quick Reference

### Terminal Commands

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
| Check remote | `git remote -v` |
| Open in VS Code | `code .` |

### VS Code Shortcuts

| Action | Shortcut |
|--------|----------|
| Source Control | `Ctrl+Shift+G` |
| Commit | `Ctrl+Enter` (in message box) |
| Terminal | `Ctrl+`` |
| Command Palette | `Ctrl+Shift+P` |
| Search files | `Ctrl+P` |

---

## 15. References

- [Git Documentation](https://git-scm.com/doc)
- [GitHub Guides](https://guides.github.com/)
- [VS Code Docs](https://code.visualstudio.com/docs)
- [VS Code Git Integration](https://code.visualstudio.com/docs/sourcecontrol/overview)
- [GitLens Extension](https://gitlens.amod.io/)
- [Git Cheat Sheet](https://education.github.com/git-cheat-sheet-education.pdf)
