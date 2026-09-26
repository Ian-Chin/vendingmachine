#!/bin/bash
# Manual smoke tests for the welcome / login layer.
# Each case pipes a keystroke script into the binary and strips ANSI colours.
cd "$(dirname "$0")" || exit 1

nasm -f elf64 -o vending.o vending.asm || exit 1
ld -o vending vending.o || exit 1

strip_ansi() { sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g'; }

run_case() {
    local name="$1" keys="$2"
    echo "##### $name"
    printf "$keys" | ./vending 2>/dev/null | strip_ansi | grep -vE '^[[:space:]]*$'
    echo "##### exit=$?"
    echo
}

run_case "supplier login OK -> restock -> exit"   '2\nadmin\nadmin123\n\n6\n\nX\n'
run_case "supplier login wrong password"          '2\nadmin\nwrongpw\n\n2\nadmin\nnope\n\n2\nadmin\nbad\n\n\nX\n'
run_case "customer-role account rejected"         '2\njohn\npass123\n\n\nX\n'
run_case "guest customer, supplier option denied" '1\n6\n\nX\n'
run_case "logout drops supplier privileges"       '2\nadmin\nadmin123\n\nL\n1\n6\n\nX\n'

echo "##### missing users.txt"
mv users.txt users.txt.bak
printf '2\nadmin\nadmin123\n\n\nX\n' | ./vending 2>/dev/null | strip_ansi | grep -E 'ERROR'
mv users.txt.bak users.txt
echo
