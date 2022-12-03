#!/bin/bash
forge coverage --report lcov
lcov --remove lcov.info 'test/*' 'script/*' --output-file lcov.info --rc lcov_branch_coverage=1
genhtml lcov.info -o report --branch-coverage
