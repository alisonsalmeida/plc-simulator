FLUTTER ?= /usr/local/bin/flutter/bin/flutter
DART ?= /usr/local/bin/flutter/bin/dart

.PHONY: check run web vault

check:
	$(FLUTTER) analyze
	$(FLUTTER) test
	cd packages/plc_core && $(DART) analyze && $(DART) test

run:
	$(FLUTTER) run -d chrome

web:
	$(FLUTTER) build web

vault:
	python3 scripts/build_vault.py
