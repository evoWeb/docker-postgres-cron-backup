all: test

test:
	# Checking for syntax errors
	@set -e; for SCRIPT in Scripts/*.sh; \
	do bash -n $$SCRIPT; done

	# Checking for bashisms (currently not failing, but only listing)
	@SCRIPT="$$(which checkbashisms)"; \
	if [ -n "$$SCRIPT" ] && [ -x "$$SCRIPT" ]; then \
		$$SCRIPT Scripts/*.sh || true; \
	else \
		echo "WARNING: skipping bashism test - you need to install checkbashism."; \
	fi

	# Checking with shellcheck (currently not failing, but only listing)
	@SCRIPT="$$(which shellcheck)"; \
	if [ -n "$$SCRIPT" ] && [ -x "$$SCRIPT" ]; then \
		$$SCRIPT Scripts/*.sh || true; \
	else \
		echo "WARNING: skipping shellcheck test - you need to install shellcheck."; \
	fi
