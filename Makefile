.PHONY: devlog-update devlog-pr-body doc-automation-test

devlog-update: ## Update generated weekly devlog blocks from the previous calendar week
	@PYTHONPATH=Scripts python3 -m doc_automation.devlog \
		--markdown docs/guides/devlog.md \
		--html docs/devlog.html \
		--repo-url https://github.com/dfakkeldy/VisualTimer

devlog-pr-body: ## Generate the review checklist and AI-assisted draft for the weekly devlog PR
	@PYTHONPATH=Scripts python3 -m doc_automation.curate_devlog \
		--project-name "Turn Timer" \
		--markdown docs/guides/devlog.md \
		--html docs/devlog.html \
		--repo-url https://github.com/dfakkeldy/VisualTimer \
		--extra-guidance "Turn Timer is being rebranded from Visual Timer. Avoid claiming the rebrand, public launch, download counts, revenue, or active users are complete unless present in the factual digest." \
		--extra-checklist "Verify that any Turn Timer vs. Visual Timer naming, beta, or App Store claim matches the current rebrand state before posting." \
		--out "$${DEVLOG_PR_BODY:-devlog-pr-body.md}"

doc-automation-test: ## Run the doc-automation Python unit tests
	@PYTHONPATH=Scripts python3 -m unittest discover -s Scripts/doc_automation/tests -t Scripts -v
