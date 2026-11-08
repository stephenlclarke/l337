SHELL := /bin/bash
.DEFAULT_GOAL := help
RELEASE_PLAN ?= dist/release-plan.json
ELITE_SANITIZERS ?= 0
README_MEDIA_ARGS ?=
.PHONY: release-plan publish-release release-readme release
.PHONY: tutorial-readme-check sanitizer-checkpoints-check native-runner-check instance-equality-check ci-capture-check change-scope-check help build run test unit-ci local-runner-check coverage coverage-check threads threads-full address sanitizers sanitizers-check leaks readme-media readme-screenshot-preview induction-ark-model induction-crew-log-model ships ships-check showroom-data showroom-import showroom-check liberator-design hull-designs mission-packs-check flight-controls-check package-macos homebrew-cask homebrew-cask-check sonar ci retired-hulls-check
help:
	@printf '%s\n' 'build run test unit-ci tutorial-readme-check sanitizer-checkpoints-check instance-equality-check local-runner-check ci-capture-check change-scope-check coverage-check threads threads-full address sanitizers sanitizers-check leaks readme-media readme-screenshot-preview induction-ark-model induction-crew-log-model ships ships-check showroom-data showroom-import showroom-check liberator-design hull-designs mission-packs-check flight-controls-check release-plan package-macos publish-release release-readme release homebrew-cask homebrew-cask-check sonar ci retired-hulls-check'
build:
	swift build
run:
	./script/build_and_run.sh
test:
	swift test
unit-ci: instance-equality-check change-scope-check
	python3 Tools/CI/isolated_units.py
tutorial-readme-check:
	PYTHONDONTWRITEBYTECODE=1 python3 Tools/CI/tutorial_readme_parity.py
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_tutorial_readme_parity.py'
change-scope-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_change_scope.py'
local-runner-check:
	python3 -m unittest discover -s Tools/CI -p 'test_local_runner.py'
coverage coverage-check: sanitizer-checkpoints-check
	python3 Tools/CI/quality_phase_checkpoints.py normal
sanitizer-checkpoints-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_sanitizer_checkpoints.py'
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_quality_phase_checkpoints.py'
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_hosted_quality_evidence.py'
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_m01_normal_attestation.py'
threads:
	swift test --scratch-path .build/tsan --sanitize=thread --jobs 1 -Xswiftc -disable-batch-mode
address:
	ASAN_OPTIONS=detect_leaks=0 swift test --scratch-path .build/asan --sanitize=address --jobs 1 -Xswiftc -disable-batch-mode --no-parallel
threads-full: threads
sanitizers:
	$(MAKE) threads
	$(MAKE) address
sanitizers-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_optional_sanitizers.py'
leaks: sanitizer-checkpoints-check
	python3 Tools/CI/quality_phase_checkpoints.py leaks
# Uses the same real capture scene and imageForGame path; no published media is replaced.
readme-screenshot-preview:
	swift run --jobs 1 -Xswiftc -disable-batch-mode L337 --readme-screenshot-preview

readme-media:
ifeq ($(filter --medusa-only,$(README_MEDIA_ARGS)),)
	swift run --jobs 1 -Xswiftc -disable-batch-mode L337 --readme-media $(README_MEDIA_ARGS)
	mkdir -p Resources
	iconutil -c icns .build/L337.iconset -o Resources/L337.icns
else
	python3 Tools/showroom/ship-reference.py --readme-medusa
endif

induction-ark-model:
	python3 Tools/export-induction-ark-model.py

induction-crew-log-model:
	python3 Tools/export-induction-ark-model.py --crew-log
ships showroom-data:
	python3 Tools/showroom/ship-reference.py
ships-check:
	python3 Tools/showroom/ship-reference.py --check
showroom-import:
	python3 Tools/showroom/build-catalogue.py --models "$(SHOWROOM_MODELS)" --expansions "$(SHOWROOM_EXPANSIONS)" $(if $(SHOWROOM_MODEL_CACHE),--model-cache "$(SHOWROOM_MODEL_CACHE)")
showroom-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/showroom -p 'test_*.py'
sonar:
	./script/sonar.sh
mission-packs-check:
	swift run --build-system native --jobs 1 -Xswiftc -disable-batch-mode L337 --validate-mission-pack docs/mission-packs/courier.toml
flight-controls-check:
	PYTHONDONTWRITEBYTECODE=1 python3 Tools/generate-flight-controls.py --repo-root . --check
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/tests -p 'test_flight_controls.py'
release-plan:
	python3 Tools/distribution/release_version.py --output "$(RELEASE_PLAN)"
package-macos:
	python3 Tools/distribution/package_macos.py --release-plan "$(RELEASE_PLAN)"
publish-release:
	python3 Tools/distribution/release_macos.py publish --release-plan "$(RELEASE_PLAN)"
release-readme:
	python3 Tools/distribution/release_macos.py readme --release-plan "$(RELEASE_PLAN)"
release: release-plan
	$(MAKE) package-macos
	$(MAKE) publish-release
homebrew-cask:
	python3 Tools/distribution/homebrew_cask.py --release-plan "$(RELEASE_PLAN)" $(if $(ELITE_HOMEBREW_TAP),--tap "$(ELITE_HOMEBREW_TAP)")
homebrew-cask-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/distribution -p 'test_*.py'
	python3 Tools/distribution/homebrew_cask.py --check
ci-capture-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_crash_artifacts.py'
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_passive_failure_evidence.py'
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_sh058_operation_journal.py'
native-runner-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_native_runner.py'

retired-hulls-check:
	PYTHONDONTWRITEBYTECODE=1 python3 Tools/distribution/retired_hull_resources.py

ci: change-scope-check retired-hulls-check sanitizers-check native-runner-check instance-equality-check ci-capture-check flight-controls-check homebrew-cask-check ships-check showroom-check mission-packs-check coverage-check leaks

# Gate all CI work before any build, including parallel make. Standalone targets stay unchanged.
ifneq ($(filter ci,$(MAKECMDGOALS)),)
change-scope-check retired-hulls-check sanitizers-check native-runner-check instance-equality-check ci-capture-check flight-controls-check homebrew-cask-check ships-check showroom-check mission-packs-check coverage-check leaks sanitizer-checkpoints-check: | tutorial-readme-check
endif

ifeq ($(ELITE_SANITIZERS),1)
ci:
	$(MAKE) sanitizers
endif

instance-equality-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_script_instance_equality.py'
	python3 Tools/CI/script_instance_equality.py
