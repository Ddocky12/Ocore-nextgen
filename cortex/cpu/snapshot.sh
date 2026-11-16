#!/system/bin/sh

DIR="/data/adb/modules/Ocore/backup"
LOG="$DIR/backup.log"

# Pastikan backup.log ada
[ -f "$LOG" ] || exit 1

# Ambil snapshot terakhir yang tercatat di log
LATEST=$(grep 'snapshot committed:' "$LOG" | tail -n 1 | sed 's/.*snapshot committed: //')

# Validasi hasil
[ -n "$LATEST" ] || exit 1
[ -f "$LATEST" ] || exit 1

LATEST_NAME=$(basename "$LATEST")
LATEST_ID="${LATEST_NAME%.rbk}"

# Hapus semua snapshot lama
for file in "$DIR"/*.rbk; do
    [ -f "$file" ] || continue

    name=$(basename "$file")

    if [ "$name" != "$LATEST_NAME" ]; then
        rm -f "$file"
        rm -f "$DIR/${name}.txt"
    fi
done

# Hapus .rbk.txt lama yang orphan
for file in "$DIR"/*.rbk.txt; do
    [ -f "$file" ] || continue

    name=$(basename "$file" .rbk.txt)

    if [ "$name" != "$LATEST_ID" ]; then
        rm -f "$file"
    fi
done

exit 0