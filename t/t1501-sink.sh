#!/bin/sh

test_description='Test "stg sink"'

. ./test-lib.sh

test_expect_success 'Initialize StGit stack' '
    echo 0 >> f0 &&
    stg add f0 &&
    git commit -m initial &&
    echo 1 >> f1 &&
    stg add f1 &&
    git commit -m p1 &&
    echo 2 >> f2 &&
    stg add f2 &&
    git commit -m p2 &&
    echo 3 >> f3 &&
    stg add f3 &&
    git commit -m p3 &&
    echo 4 >> f4 &&
    stg add f4 &&
    git commit -m p4 &&
    echo 22 >> f2 &&
    stg add f2 &&
    git commit -m p22 &&
    stg init &&
    stg uncommit p22 p4 p3 p2 p1 &&
    stg pop -a
'

if test -z "$STG_RUST"; then
test_expect_success 'sink default without applied patches' '
    command_error stg sink 2>err &&
    grep -e "No patches to sink" err
'
else
test_expect_success 'sink default without applied patches' '
    command_error stg sink 2>&1 |
    grep -e "No patches applied"
'
fi

test_expect_success 'sink and reorder specified without applied patches' '
    stg sink p2 p1 &&
    test "$(echo $(stg series --applied --noprefix))" = "p2 p1"
'

if test -z "$STG_RUST"; then
test_expect_success 'attempt sink below unapplied' '
    command_error stg sink --to=p4 2>err &&
    grep -e "Cannot sink below p4 since it is not applied" err
'
else
test_expect_success 'attempt sink below unapplied' '
    command_error stg sink --to=p4 2>&1 |
    grep -e "cannot sink below \`p4\` since it is not applied"
'
fi

test_expect_success 'sink patches to the bottom of the stack' '
    stg sink p4 p3 p2 &&
    test "$(echo $(stg series --applied --noprefix))" = "p4 p3 p2 p1"
'

test_expect_success 'sink current below a target' '
    stg sink --to=p2 &&
    test "$(echo $(stg series --applied --noprefix))" = "p4 p3 p1 p2"
'

test_expect_success 'bring patches forward' '
    stg sink --to=p2 p3 p4 &&
    test "$(echo $(stg series --applied --noprefix))" = "p1 p3 p4 p2"
'

test_expect_success 'sink specified patch below a target' '
    stg sink --to=p3 p2 &&
    test "$(echo $(stg series --applied --noprefix))" = "p1 p2 p3 p4"
'

test_expect_success 'sink --nopush' '
    stg sink --nopush --to=p2 &&
    test "$(echo $(stg series --applied --noprefix))" = "p1 p4" &&
    test "$(echo $(stg series --unapplied --noprefix))" = "p2 p3 p22"
'

test_expect_success 'sink --nopush with multiple patches' '
    stg sink --nopush p1 p2 p3 &&
    test "$(echo $(stg series --applied --noprefix))" = "p1 p2 p3" &&
    test "$(echo $(stg series --unapplied --noprefix))" = "p4 p22" &&
    stg goto p4
'

if test -z "$STG_RUST"; then
test_expect_success 'attempt sink with same to and target' '
    command_error stg sink --to=p3 p3 2>err &&
    grep -e "Cannot have a sinked patch as target" err &&
    rm err
'
else
test_expect_success 'attempt sink with same to and target' '
    command_error stg sink --to=p3 p3 2>&1 |
    grep -e "target patch \`p3\` may not also be a patch to sink"
'
fi

test_expect_success 'sink with conflict' '
    conflict stg sink --to=p2 p22 &&
    test "$(echo $(stg series --applied --noprefix))" = "p1 p22" &&
    test "$(echo $(stg status))" = "DU f2"
'

test_done
