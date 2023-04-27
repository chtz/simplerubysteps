#!/bin/bash

dirs=(
    "callback"
    "callback-2"
    "hello-world"
    "hello-world-2"
    "hello-world-3"
    "permissions"
    # "sample1" # FIXME flaky test
    "sample2"
    "sample3"
    "error1"
)

run_tests() {
    for dir in "${dirs[@]}"; do
        cd "$dir"
        if ! ./test.sh; then
            exit 1
        fi
        cd ..
    done
}

run_tests

echo "*** All tests passed! ***"
