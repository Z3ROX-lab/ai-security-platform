# VS Code Guide - Best Practices

> This guide covers VS Code setup and usage for the AI Security Platform project, optimized for WSL2, Kubernetes, and GitOps workflows.

---

## 1. Installation

### 1.1 Install VS Code on Windows

1. Download from: https://code.visualstudio.com/
2. Run installer with default options
3. ✅ Check "Add to PATH" option

### 1.2 First Launch from WSL
```bash
cd ~/work/ai-security-platform
code .
```

VS Code will:
- Detect WSL automatically
- Install VS Code Server in Ubuntu
- Open connected to your WSL filesystem

---

## 2. Essential Extensions

### 2.1 Must-Have Extensions

| Extension | Purpose | Install Command |
|-----------|---------|-----------------|
| **Remote - WSL** | Edit files in WSL | Auto-installed |
| **GitLens** | Advanced Git features | `ext install eamodio.gitlens` |
| **Kubernetes** | Cluster navigation | `ext install ms-kubernetes-tools.vscode-kubernetes-tools` |
| **HashiCorp Terraform** | Terraform syntax | `ext install hashicorp.terraform` |
| **YAML** | YAML validation | `ext install redhat.vscode-yaml` |
| **Markdown Preview** | Preview docs | `ext install shd101wyy.markdown-preview-enhanced` |

### 2.2 Install Extensions via Command Palette

1. Press `Ctrl+Shift+X`
2. Search extension name
3. Click **Install**

### 2.3 Install Extensions via Terminal
```bash
code --install-extension eamodio.gitlens
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension hashicorp.terraform
code --install-extension redhat.vscode-yaml
code --install-extension shd101wyy.markdown-preview-enhanced
```

---

## 3. WSL Integration

### 3.1 How It Works
```
┌─────────────────────────────────────────────────────┐
│                    Windows 11                        │
│  ┌───────────────────────────────────────────────┐  │
│  │              VS Code (GUI)                     │  │
│  └───────────────────┬───────────────────────────┘  │
│                      │ Remote Connection            │
│  ┌───────────────────▼───────────────────────────┐  │
│  │                  WSL2 Ubuntu                   │  │
│  │  ┌─────────────────────────────────────────┐  │  │
│  │  │          VS Code Server                  │  │  │
│  │  │   ~/work/ai-security-platform/          │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### 3.2 Open Project from WSL
```bash
# Navigate to project
cd ~/work/ai-security-platform

# Open in VS Code
code .

# Open specific file
code README.md

# Open specific folder
code phases/phase-01/
```

### 3.3 Verify WSL Connection

Look at bottom-left corner of VS Code:
- ✅ Shows **"WSL: Ubuntu"** = Connected to WSL
- ❌ Shows nothing = Running on Windows (wrong!)

---

## 4. Git Integration

### 4.1 Source Control Panel

| Action | How |
|--------|-----|
| Open Source Control | `Ctrl+Shift+G` |
| Stage file | Click **+** next to file |
| Stage all | Click **+** next to "Changes" |
| Unstage file | Click **-** next to staged file |
| View diff | Click on file name |
| Commit | Type message + click **✓** |
| Push | Click **...** → Push (or Sync) |
| Pull | Click **...** → Pull |

### 4.2 GitLens Features

| Feature | How to Access |
|---------|---------------|
| File history | Right-click file → GitLens → File History |
| Line blame | Hover over line (shows who/when) |
| Compare branches | Command Palette → GitLens: Compare |
| View stashes | Source Control → Stashes section |

### 4.3 Useful Git Commands in VS Code

Open Command Palette (`Ctrl+Shift+P`):

| Command | What it does |
|---------|--------------|
| `Git: Clone` | Clone a repository |
| `Git: Checkout to` | Switch branch |
| `Git: Create Branch` | Create new branch |
| `Git: Pull` | Pull from remote |
| `Git: Push` | Push to remote |
| `Git: Undo Last Commit` | Undo last commit |

---

## 5. Terminal Integration

### 5.1 Open Terminal

- Shortcut: `` Ctrl+` `` (backtick)
- Menu: Terminal → New Terminal

### 5.2 Terminal Tips

| Action | How |
|--------|-----|
| New terminal | `` Ctrl+Shift+` `` |
| Split terminal | `Ctrl+Shift+5` |
| Switch terminals | Click dropdown or `Ctrl+PageDown` |
| Clear terminal | `Ctrl+L` or type `clear` |
| Kill terminal | Click trash icon |

### 5.3 Run Commands Directly
```bash
# Terraform commands
terraform init
terraform plan
terraform apply

# Kubernetes commands
kubectl get pods -A
kubectl logs -f deployment/argocd-server -n argocd

# Docker commands
docker ps
docker logs container_name
```

---

## 6. Kubernetes Integration

### 6.1 Setup Kubernetes Extension

1. Install **Kubernetes** extension
2. Extension auto-detects kubeconfig
3. Cluster appears in sidebar (Kubernetes icon)

### 6.2 Kubernetes Explorer

| Feature | What you can do |
|---------|-----------------|
| **Clusters** | View nodes, namespaces |
| **Namespaces** | Expand to see resources |
| **Pods** | View logs, terminal, describe |
| **Deployments** | Scale, restart, describe |
| **Services** | View endpoints |

### 6.3 Useful Actions

Right-click on any resource:
- **Describe** → `kubectl describe`
- **Delete** → `kubectl delete`
- **Terminal** → Shell into pod
- **Logs** → View pod logs

### 6.4 Apply Manifests

Right-click on YAML file:
- **Apply** → `kubectl apply -f file.yaml`
- **Delete** → `kubectl delete -f file.yaml`

---

## 7. Terraform Integration

### 7.1 Features

| Feature | Description |
|---------|-------------|
| Syntax highlighting | Color-coded `.tf` files |
| Auto-completion | Resources, attributes |
| Format on save | Auto-formats code |
| Validation | Shows errors inline |

### 7.2 Enable Format on Save

1. Open Settings (`Ctrl+,`)
2. Search "format on save"
3. ✅ Check "Editor: Format On Save"

### 7.3 Terraform Commands

Open Command Palette (`Ctrl+Shift+P`):
- `Terraform: init`
- `Terraform: plan`
- `Terraform: apply`
- `Terraform: validate`

---

## 8. Markdown Preview

### 8.1 Preview Documentation

| Action | Shortcut |
|--------|----------|
| Open preview (side) | `Ctrl+K V` |
| Open preview (full) | `Ctrl+Shift+V` |

### 8.2 Live Preview

With **Markdown Preview Enhanced**:
- Real-time preview as you type
- Table of contents
- Export to PDF/HTML

---

## 9. Keyboard Shortcuts

### 9.1 Essential Shortcuts

| Action | Shortcut |
|--------|----------|
| Command Palette | `Ctrl+Shift+P` |
| Quick Open (files) | `Ctrl+P` |
| Search in files | `Ctrl+Shift+F` |
| Toggle terminal | `` Ctrl+` `` |
| Toggle sidebar | `Ctrl+B` |
| Split editor | `Ctrl+\` |
| Close tab | `Ctrl+W` |
| Save file | `Ctrl+S` |
| Save all | `Ctrl+K S` |

### 9.2 Editor Shortcuts

| Action | Shortcut |
|--------|----------|
| Find | `Ctrl+F` |
| Replace | `Ctrl+H` |
| Go to line | `Ctrl+G` |
| Comment line | `Ctrl+/` |
| Move line up/down | `Alt+↑/↓` |
| Duplicate line | `Shift+Alt+↓` |
| Delete line | `Ctrl+Shift+K` |
| Multi-cursor | `Alt+Click` |
| Select all occurrences | `Ctrl+Shift+L` |

### 9.3 Navigation Shortcuts

| Action | Shortcut |
|--------|----------|
| Go to definition | `F12` |
| Peek definition | `Alt+F12` |
| Go back | `Alt+←` |
| Go forward | `Alt+→` |
| Explorer panel | `Ctrl+Shift+E` |
| Source Control | `Ctrl+Shift+G` |
| Extensions | `Ctrl+Shift+X` |

---

## 10. Settings Recommendations

### 10.1 Open Settings

- GUI: `Ctrl+,`
- JSON: `Ctrl+Shift+P` → "Open Settings (JSON)"

### 10.2 Recommended Settings

Add to `settings.json`:
```json
{
  // Editor
  "editor.fontSize": 14,
  "editor.tabSize": 2,
  "editor.formatOnSave": true,
  "editor.wordWrap": "on",
  "editor.minimap.enabled": false,
  
  // Files
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 1000,
  "files.trimTrailingWhitespace": true,
  
  // Terminal
  "terminal.integrated.defaultProfile.linux": "bash",
  "terminal.integrated.fontSize": 13,
  
  // Git
  "git.autofetch": true,
  "git.confirmSync": false,
  "git.enableSmartCommit": true,
  
  // Kubernetes
  "vs-kubernetes.outputFormat": "yaml",
  
  // Terraform
  "terraform.experimentalFeatures.validateOnSave": true,
  
  // YAML (for Kubernetes manifests)
  "yaml.schemas": {
    "kubernetes": "*.yaml"
  }
}
```

---

## 11. Project-Specific Setup

### 11.1 Workspace Settings

Create `.vscode/settings.json` in your project:
```json
{
  "files.exclude": {
    "**/.terraform": true,
    "**/*.tfstate*": true
  },
  "editor.tabSize": 2,
  "yaml.schemas": {
    "kubernetes": [
      "phases/**/argocd/*.yaml",
      "phases/**/manifests/*.yaml"
    ]
  }
}
```

### 11.2 Recommended Extensions for Project

Create `.vscode/extensions.json`:
```json
{
  "recommendations": [
    "ms-vscode-remote.remote-wsl",
    "eamodio.gitlens",
    "ms-kubernetes-tools.vscode-kubernetes-tools",
    "hashicorp.terraform",
    "redhat.vscode-yaml",
    "shd101wyy.markdown-preview-enhanced"
  ]
}
```

Team members will see "Install Recommended Extensions" prompt.

---

## 12. Troubleshooting

### 12.1 WSL Connection Issues

**Problem**: VS Code not connecting to WSL
```bash
# In Windows PowerShell
wsl --shutdown
wsl
```

Then reopen VS Code.

**Problem**: "Unsafe repository" warning
```bash
git config --global --add safe.directory /home/username/work/ai-security-platform
```

### 12.2 Extension Issues

**Problem**: Extension not working in WSL

Some extensions need to be installed in WSL:
1. Open Extensions (`Ctrl+Shift+X`)
2. Look for "Install in WSL" button
3. Click to install in WSL

### 12.3 Terminal Issues

**Problem**: Terminal opens in Windows, not WSL

1. Open Settings (`Ctrl+,`)
2. Search "terminal default profile"
3. Set to "Ubuntu (WSL)"

---

## 13. Quick Reference

### Daily Workflow
```
1. Open project:     code . (from WSL terminal)
2. Edit files:       Click in Explorer
3. View changes:     Ctrl+Shift+G
4. Stage:            Click + on files
5. Commit:           Type message + ✓
6. Push:             Click Sync
7. Run commands:     Ctrl+` (terminal)
```

### File Operations

| Action | Method |
|--------|--------|
| New file | `Ctrl+N` or right-click → New File |
| New folder | Right-click → New Folder |
| Rename | `F2` |
| Delete | Right-click → Delete |
| Move | Drag and drop |

### Command Palette Commands

| Type | Then |
|------|------|
| `>` | Run command |
| `@` | Go to symbol in file |
| `#` | Go to symbol in workspace |
| `:` | Go to line number |
| (nothing) | Open file |

---

## 14. References

- [VS Code Documentation](https://code.visualstudio.com/docs)
- [VS Code WSL Guide](https://code.visualstudio.com/docs/remote/wsl)
- [Keyboard Shortcuts Reference](https://code.visualstudio.com/shortcuts/keyboard-shortcuts-windows.pdf)
