# Release Process

## Pipeline

Code goes from the develop branch to the staging environment every night. A release candidate is cut on Tuesday and promoted to production on Thursday after sign-off.

## Hotfixes

A hotfix branch is cut from the last production tag, deployed to staging for a smoke test and then promoted. Hotfixes still need the QA sign-off described in the QA vendor process.
