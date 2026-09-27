# code-blocks - repo housekeeping
#
#   make clean       # remove terraform caches + EMPTY state in every folder
#   make clean-dry   # show what clean would do, without deleting anything
#
# Safety: a folder is only cleaned when its terraform.tfstate tracks ZERO
# resources. If the state still holds live infra (servers running), or the
# state can't be read, that folder is left completely untouched.
#
SHELL := /bin/bash
ROOT  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

.PHONY: clean clean-dry _clean

clean:     ; @$(MAKE) --no-print-directory _clean DRY=0
clean-dry: ; @$(MAKE) --no-print-directory _clean DRY=1

_clean:
	@echo "Scanning $(ROOT) for terraform artifacts ..."
	@dirs=$$( { \
	    find "$(ROOT)" -type f -name '*.tf'             -exec dirname {} \; ; \
	    find "$(ROOT)" -type d -name '.terraform'       -exec dirname {} \; ; \
	    find "$(ROOT)" -type f -name 'terraform.tfstate' -exec dirname {} \; ; \
	  } | sort -u ); \
	if [ -z "$$dirs" ]; then echo "  nothing to clean"; exit 0; fi; \
	for d in $$dirs; do \
	  rel="$${d#$(ROOT)/}"; \
	  sf="$$d/terraform.tfstate"; \
	  if [ -f "$$sf" ]; then \
	    n=$$(python3 -c "import json;print(len(json.load(open('$$sf')).get('resources',[])))" 2>/dev/null || echo -1); \
	    if [ "$$n" -gt 0 ] 2>/dev/null; then \
	      echo "  SKIP   $$rel  (state tracks $$n resource(s) - infra may be live)"; continue; \
	    fi; \
	    if [ "$$n" -lt 0 ] 2>/dev/null; then \
	      echo "  SKIP   $$rel  (state unreadable - left untouched)"; continue; \
	    fi; \
	  fi; \
	  if [ "$(DRY)" = "1" ]; then \
	    echo "  WOULD  $$rel  (rm .terraform/ + state files)"; \
	  else \
	    rm -rf "$$d/.terraform" \
	           "$$d"/terraform.tfstate "$$d"/terraform.tfstate.backup \
	           "$$d"/crash.log "$$d"/crash.*.log; \
	    echo "  CLEAN  $$rel"; \
	  fi; \
	done
