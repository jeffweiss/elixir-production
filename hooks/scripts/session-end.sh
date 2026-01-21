#!/bin/bash
# SessionEnd hook - reminder to capture learnings

echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionEnd\",\"additionalContext\":\"Session ending. If new patterns, conventions, or architectural decisions were discovered during this session, consider updating .claude/project-learnings.md using the /learn command.\"}}"
