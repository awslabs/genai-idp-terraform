.PHONY: test test-cicd clean

test: test-unit

test-unit:
	python -m pytest -m "unit" --ignore=idp_common/agents/testing

test-integration:
	python -m pytest -m "integration" --ignore=idp_common/agents/testing

test-cicd: test-unit-cicd

test-unit-cicd:
	pip install -e ".[test]"
	python -m pytest -m "unit" --cov=idp_common --cov-report=xml:test-reports/coverage.xml --cov-report=term --junitxml=test-reports/test-results.xml tests/

clean:
	rm -rf .pytest_cache
	rm -rf .coverage
	rm -rf coverage.xml
	rm -rf test-results.xml
	rm -rf test-reports
	rm -rf htmlcov
	rm -rf dist
	rm -rf build
	rm -rf *.egg-info
	
# A convenience target to install the idp_common library with all, dev dependencies in edit mode
dev:
	pip install -e ".[all, dev]"