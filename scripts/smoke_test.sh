#!/bin/sh

BINARY_NAME=$1
BINARY=${2:-/usr/local/bin/$BINARY_NAME}
MIGRATIONS_PATH=${3:-/migrations}
DB=/tmp/litevolve_smoke_$$.db

echo "testing $BINARY_NAME..."
$BINARY \
    --apply_version=3 \
    --db_path=$DB \
    --migrations_path=$MIGRATIONS_PATH \
    --init_seeds || exit 1

FAILS=0
assert_eq() {
    RESULT=$(sqlite3 "$DB" "$1")
    if [ "$RESULT" = "$2" ]; then
        echo "  ok  $3"
    else
        echo "  FAIL $3: expected=$2 got=$RESULT"
        FAILS=$((FAILS+1))
    fi
}

assert_eq "PRAGMA user_version"                                             "3"  "schema at v3"
assert_eq "SELECT COUNT(*) FROM observation_sites"                          "3"  "3 observation_sites (v1 seed)"
assert_eq "SELECT COUNT(*) FROM birders"                                    "8"  "8 birders (v1 seed)"
assert_eq "SELECT COUNT(*) FROM time_slots"                                 "32" "32 time_slots (v1 seed)"
assert_eq "SELECT COUNT(*) FROM sightings"                                  "3"  "3 sightings (v1 seed)"
assert_eq "SELECT COUNT(*) FROM birders WHERE mentor_birder_id IS NOT NULL" "5"  "5 mentored birders (v3 seed)"

rm -f "$DB"
[ "$FAILS" -eq 0 ] \
    && echo "$BINARY_NAME: all checks passed" \
    || { echo "$BINARY_NAME: FAILED ($FAILS check(s))"; exit 1; }
