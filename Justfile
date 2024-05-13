[no-exit-message]
test *args='--stale':
    mix test {{ args }}

watch cmd='just test':
    find {lib,test} -name '*.ex*' | entr -dc {{ cmd }}
