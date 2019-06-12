#!/usr/bin/env zsh

export TEST_NAME=$2
envsubst '$TEST_NAME' < run_one_test.subx > /tmp/run_one_test.subx

subx --debug translate [0-9]*.subx apps/subx-common.subx $1 /tmp/run_one_test.subx -o /tmp/a.elf
subx --debug --trace run /tmp/a.elf
