#!/usr/bin/env bash
#
# Verification script for Elixir Production Plugin
#
# Checks that the plugin is correctly installed and configured.

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "🔍 Verifying Elixir Production Plugin Installation"
echo ""

# Check 1: Plugin directory
echo -n "1. Plugin directory... "
if [[ -d ~/.claude/plugins/elixir-production ]]; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗${NC}"
  echo "   Plugin directory not found at: ~/.claude/plugins/elixir-production"
  exit 1
fi

# Check 2: plugin.json
echo -n "2. Plugin manifest... "
if [[ -f ~/.claude/plugins/elixir-production/.claude-plugin/plugin.json ]]; then
  if jq empty ~/.claude/plugins/elixir-production/.claude-plugin/plugin.json 2>/dev/null; then
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${RED}✗${NC}"
    echo "   plugin.json has invalid JSON syntax"
    exit 1
  fi
else
  echo -e "${RED}✗${NC}"
  echo "   plugin.json not found"
  exit 1
fi

# Check 3: Core agents
echo -n "3. Core agents... "
missing_agents=()
for agent in elixir-architect elixir-developer elixir-reviewer test-designer; do
  if [[ ! -f ~/.claude/plugins/elixir-production/agents/${agent}.md ]]; then
    missing_agents+=("$agent")
  fi
done

if [[ ${#missing_agents[@]} -eq 0 ]]; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${YELLOW}⚠${NC}"
  echo "   Missing agents: ${missing_agents[*]}"
fi

# Check 4: Skills
echo -n "4. Skills... "
missing_skills=()
for skill in elixir-patterns production-quality; do
  if [[ ! -f ~/.claude/plugins/elixir-production/skills/${skill}/SKILL.md ]]; then
    missing_skills+=("$skill")
  fi
done

if [[ ${#missing_skills[@]} -eq 0 ]]; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${YELLOW}⚠${NC}"
  echo "   Missing skills: ${missing_skills[*]}"
fi

# Check 5: Commands
echo -n "5. Commands... "
missing_commands=()
for cmd in precommit feature review; do
  if [[ ! -f ~/.claude/plugins/elixir-production/commands/${cmd}.md ]]; then
    missing_commands+=("$cmd")
  fi
done

if [[ ${#missing_commands[@]} -eq 0 ]]; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${YELLOW}⚠${NC}"
  echo "   Missing commands: ${missing_commands[*]}"
fi

# Check 6: Hooks
echo -n "6. Hooks configuration... "
if [[ -f ~/.claude/plugins/elixir-production/hooks/hooks.json ]]; then
  if jq empty ~/.claude/plugins/elixir-production/hooks/hooks.json 2>/dev/null; then
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${RED}✗${NC}"
    echo "   hooks.json has invalid JSON syntax"
    exit 1
  fi
else
  echo -e "${RED}✗${NC}"
  echo "   hooks.json not found"
  exit 1
fi

# Check 7: Hook scripts
echo -n "7. Hook scripts... "
missing_scripts=()
for script in validate-precommit.sh check-complexity.sh validate-dependencies.sh; do
  if [[ ! -f ~/.claude/plugins/elixir-production/hooks/scripts/${script} ]]; then
    missing_scripts+=("$script")
  elif [[ ! -x ~/.claude/plugins/elixir-production/hooks/scripts/${script} ]]; then
    echo -e "${YELLOW}⚠${NC}"
    echo "   Script not executable: $script"
    echo "   Run: chmod +x ~/.claude/plugins/elixir-production/hooks/scripts/*.sh"
    exit 1
  fi
done

if [[ ${#missing_scripts[@]} -eq 0 ]]; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${YELLOW}⚠${NC}"
  echo "   Missing scripts: ${missing_scripts[*]}"
fi

# Check 8: Templates
echo -n "8. Templates... "
missing_templates=()
for template in AGENTS.md CLAUDE.md project-learnings.md spike-debt.md; do
  if [[ ! -f ~/.claude/plugins/elixir-production/templates/${template} ]]; then
    missing_templates+=("$template")
  fi
done

if [[ ${#missing_templates[@]} -eq 0 ]]; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${YELLOW}⚠${NC}"
  echo "   Missing templates: ${missing_templates[*]}"
fi

# Check 9: Documentation
echo -n "9. Documentation... "
if [[ -f ~/.claude/plugins/elixir-production/README.md ]]; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${YELLOW}⚠${NC}"
  echo "   README.md not found"
fi

echo ""
echo -e "${GREEN}✅ Plugin installation verified!${NC}"
echo ""
echo "Next steps:"
echo "1. Navigate to an Elixir project: cd /path/to/your/elixir/project"
echo "2. Try: claude-code /precommit"
echo "3. Try: claude-code /feature \"Add user authentication\""
echo "4. Try: claude-code /review lib/"
echo ""
echo "For more information, see:"
echo "  ~/.claude/plugins/elixir-production/README.md"
