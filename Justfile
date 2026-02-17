[no-exit-message]
test *args='--stale':
    mix test {{ args }}

watch cmd='just test':
    find {lib,test} -name '*.ex*' | entr -dc {{ cmd }}

# Pre-commit gate: run by the global TDD commit-msg hook
pre-commit:
    mix test --stale

# Pre-push gate: full test suite before pushing
pre-push:
    mix test
