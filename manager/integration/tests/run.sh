#!/bin/bash

#pytest -v "$@"
set -x
behave -f behave_html_formatter:HTMLFormatter -o report.html -f pretty --no-capture --junit --junit-directory /tmp/test-report
cp report.html /tmp/test-report/
