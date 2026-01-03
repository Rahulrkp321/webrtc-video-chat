# 🌳 Git Branch Helper Guide

## Quick Reference Commands

### 📍 Check Current Branch
```bash
git branch
```

### 🆕 Start a New Day (Create New Branch)
```bash
# Replace X with day number (e.g., day-2, day-3)
git checkout -b day-X
git push -u origin day-X
```

### 💾 Save Your Work (Commit & Push)
```bash
git add .
git commit -m "Day X: Description of what you did"
git push
```

### 🔄 Switch to Different Branch
```bash
git checkout day-1    # Go to day-1
git checkout day-2    # Go to day-2
git checkout main     # Go to main
```

### 📋 See All Branches
```bash
git branch -a
```

### 🔗 Merge a Day into Main
```bash
git checkout main
git merge day-X
git push
```

---

## 🗓️ Daily Workflow

### Morning (Start of Day):
```bash
# Check current branch
git branch

# If starting new day, create new branch from previous day
git checkout day-X           # X = previous day
git checkout -b day-Y        # Y = new day
git push -u origin day-Y
```

### During the Day:
```bash
# Save work frequently
git add .
git commit -m "Work in progress: feature description"
git push
```

### Evening (End of Day):
```bash
# Final commit
git add .
git commit -m "Day X Complete: Summary of accomplishments"
git push
```

---

## 📊 Branch Naming Convention

| Day | Branch Name | Purpose |
|-----|-------------|---------|
| 1 | `day-1` | Environment Setup |
| 2 | `day-2` | Database Schema |
| 3 | `day-3` | Stored Procedures |
| 4 | `day-4` | Authentication API |
| 5 | `day-5` | Auth UI |
| 6 | `day-6` | Signaling Server |
| 7 | `day-7` | WebRTC Core |
| 8 | `day-8` | Video Call Flow |
| 9 | `day-9` | Call Controls |
| 10 | `day-10` | Contacts & History |
| 11 | `day-11` | Polish & Testing |
| 12 | `day-12` | Final Documentation |

---

## ⚠️ Common Issues & Solutions

### Issue: "Please commit your changes before switching branches"
```bash
# Option 1: Commit your changes
git add .
git commit -m "Saving work"
git checkout other-branch

# Option 2: Stash changes temporarily
git stash
git checkout other-branch
git stash pop   # To get changes back
```

### Issue: "Merge conflict"
```bash
# Open conflicted files, look for:
# <<<<<<< HEAD
# (your changes)
# =======
# (other changes)
# >>>>>>> branch-name

# Manually edit to keep what you want, then:
git add .
git commit -m "Resolved merge conflict"
```

### Issue: "Your branch is behind"
```bash
git pull
```

---

## 🎯 Best Practices

1. **Commit Often** - Small, frequent commits are better
2. **Write Clear Messages** - Explain WHAT changed and WHY
3. **Push Daily** - Don't lose your work
4. **Branch Names** - Keep them simple and descriptive
5. **Don't Work on Main** - Always use feature branches

