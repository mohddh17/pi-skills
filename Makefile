SHELL := /bin/bash

.PHONY: help validate pack dry new publish install-local

help:
	@echo "make validate      check every skills/*/SKILL.md"
	@echo "make dry           npm pack --dry-run (what would ship)"
	@echo "make new NAME=x    scaffold skills/x/SKILL.md"
	@echo "make publish REPO=owner/repo [TOKEN=ghp_...]"
	@echo "make install-local test-install this checkout into ~/.pi/agent/settings.json"

validate:
	@node scripts/validate-skills.mjs

dry:
	@npm pack --dry-run

pack:
	@npm pack

new:
	@test -n "$(NAME)" || { echo "usage: make new NAME=my-skill"; exit 2; }
	@mkdir -p skills/$(NAME)
	@printf -- '---\nname: %s\ndescription: \n---\n\n# %s\n\n## When to use\n\n## Steps\n\n## Verify\n' "$(NAME)" "$(NAME)" > skills/$(NAME)/SKILL.md
	@echo "created skills/$(NAME)/SKILL.md — fill in the description, it is the routing text"

publish:
	@test -n "$(REPO)" || { echo "usage: make publish REPO=owner/repo TOKEN=ghp_..."; exit 2; }
	@GITHUB_TOKEN=$(TOKEN) ./scripts/publish.sh $(REPO)

install-local:
	@pi install "$(CURDIR)" && pi list
