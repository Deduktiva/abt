# Claude Code GitHub Issues Workflow

This document describes the established workflow for handling GitHub issues in the ABT project using Claude Code.

## 🏷️ **Issue Selection Criteria**

**Only work on issues labeled "Ready for action"** - these issues have been reviewed and are ready for implementation. Do not work on unlabeled issues or issues with other labels unless specifically instructed.

## 🔄 **Standard Issue Resolution Workflow**

### 1. **Initial Setup & Analysis**
```bash
# Check for issues labeled "Ready for action"
gh issue list --repo Deduktiva/abt --state open --label "Ready for action" --limit 20

# Get detailed issue information  
gh issue view <issue_number> --repo Deduktiva/abt
```

### 2. **Branch Management**
```bash
# Always start from master and pull latest changes
git switch master
git pull origin master

# Create feature branch for each issue
git switch -c feature/issue-<number>-<brief-description>
```

**Branch Naming Convention:**
- `feature/issue-37-customer-like-projects`
- `feature/issue-38-favicon-and-title`
- `feature/issue-39-remove-puppet-readme`

### 3. **Development Process**

#### a) **Plan and Track Work**
- Use `TodoWrite` tool to create task list for complex issues
- Break down multi-step tasks into trackable items
- Mark tasks as `in_progress` → `completed` as work progresses

#### b) **Implementation**
- Follow existing code patterns and conventions from `CLAUDE.md`
- **PREFER HAML** over ERB for view templates
- Always use `bundle exec rails` commands
- Add comprehensive tests for all new functionality

#### c) **Testing Requirements**
- **ALWAYS** run full test suite: `bundle exec rails test`
- Add unit tests for new models/helpers
- Add integration tests for new controllers/features
- Add system tests for new scripts/tools
- Ensure all tests pass before committing

### 4. **Commit and Create PR**

#### a) **Commit Changes**
```bash
# Stage all changes
git add .

# Create comprehensive commit with detailed message
git commit -m "$(cat <<'EOF'
Fix Issue #<number>: <Brief description>

<Detailed description of changes>

**<Section headers for major changes>:**
- Bullet points describing specific changes
- Technical implementation details
- Database changes, migrations, etc.

**Testing:**
- Description of tests added
- Test coverage and assertion counts
- All X tests pass with Y assertions

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

#### b) **Create PR (includes automatic push)**
```bash
# Create pull request (gh pr create automatically pushes the branch)
gh pr create --title "<Brief description>" \
  --body "$(cat <<'EOF'
## Summary
Resolves #<number>

<Detailed PR description with sections:>
### ✅ **Feature/Changes Made**
### 🧪 **Testing**  
### 📋 **Technical Details**
### Test plan checklist

🤖 Generated with [Claude Code](https://claude.ai/code)
EOF
)" --head feature/issue-<number>-<description> --base master
```

### 5. **Issue Documentation**
When creating a PR that references an issue (using "Resolves #number"), GitHub automatically links the PR to the issue. **Do not add redundant comments to the issue** that just restate what's already in the PR description.

### 6. **Post-Completion**
```bash
# Switch back to master for next issue
git switch master
git pull origin master

# Check for issues labeled "Ready for action"
gh issue list --repo Deduktiva/abt --state open --label "Ready for action" --limit 10
```

## 🎯 **Key Principles**

### **Branch Strategy**
- ✅ **One branch per issue** - keeps changes isolated
- ✅ **Feature branches** - never work directly on master (except for simple fixes)
- ✅ **Descriptive names** - easy to understand what each branch does
- ✅ **Start from master** - always pull latest changes first

### **Testing Standards** 
- ✅ **Always run full test suite** - `bundle exec rails test`
- ✅ **Add tests for new features** - unit, integration, system as appropriate
- ✅ **All tests must pass** - no exceptions before committing
- ✅ **Test edge cases** - especially for validation and error handling

### **Documentation Requirements**
- ✅ **Detailed commit messages** - explain what, why, and how
- ✅ **Comprehensive PR descriptions** - make review easy
- ✅ **Issue comments** - document the fix for future reference
- ✅ **Code comments** - only when specifically requested

### **Code Quality**
- ✅ **Follow existing patterns** - check similar code for conventions
- ✅ **HAML over ERB** - for all new view templates
- ✅ **Comprehensive error handling** - graceful failures
- ✅ **Security best practices** - never expose secrets/keys

## 🚫 **Important Don'ts**

- ❌ **Don't commit to master** directly (except for simple fixes)
- ❌ **Don't skip tests** - always run full suite
- ❌ **Don't create documentation files** unless explicitly requested
- ❌ **Don't reference commits** in issue comments until they're pushed to master
- ❌ **Don't close issues manually** - let PRs handle it
- ❌ **Don't add emojis** to code unless explicitly requested

## 📂 **Project-Specific Notes**

### **Database**
- Single IssuerCompany per installation (don't create multiple)
- Use `update_column` to bypass validations in tests when needed
- Always include database migrations for schema changes

### **Testing Environment**
- Uses ActionDispatch::IntegrationTest for controller tests
- Fixtures in `test/fixtures/` - understand the relationships
- Test helper provides database auto-migration via `maintain_test_schema!`

### **Rails Conventions**
- Uses Rails 8.0 with Hotwire/Turbo and Stimulus
- Bootstrap 5.3 for styling (without Bootstrap JS)
- Haml templating engine preferred
- Asset pipeline for images, public directory for favicon.ico

### **Deployment**
- Production uses PostgreSQL, development uses SQLite3
- Apache FOP required for PDF generation
- Manual deployment process (now scripted via Issue #40)

## 🔍 **Common Commands Reference**

```bash
# Issue management
gh issue list --repo Deduktiva/abt --state open --label "Ready for action"
gh issue view <number> --repo Deduktiva/abt
gh issue comment <number> --repo Deduktiva/abt --body "message"

# Branch management
git switch master
git pull origin master
git switch -c feature/issue-<number>-<description>

# Testing
bundle exec rails test                    # Full suite
bundle exec rails test test/models/       # Just models
bundle exec rails test test/controllers/  # Just controllers

# Rails commands (always use bundle exec)
bundle exec rails console
bundle exec rails db:migrate
bundle exec rails db:seed
bundle exec rails server

# Pull request management
gh pr create --title "..." --body "..." --head <branch> --base master
gh pr list --repo Deduktiva/abt
gh pr view <number> --repo Deduktiva/abt
```

## ✅ **Success Checklist**

Before completing any issue:
- [ ] All tests pass (`bundle exec rails test`)
- [ ] Feature branch created
- [ ] Pull request created with detailed description (automatically pushes branch)
- [ ] TodoWrite updated to mark task completed
- [ ] Returned to master branch and pulled latest changes

This workflow ensures consistent, high-quality issue resolution with proper documentation and testing.