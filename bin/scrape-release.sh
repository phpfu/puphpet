#!/usr/bin/env bash
# Scrapes the latest puphpet.zip file from puphpet.com.

DIR="$( cd -P "$( dirname "$0" )"/.. >/dev/null 2>&1 && pwd )"

SOURCE_URL=http://puphpet.com
DEST_DIR="${DIR}/tmp"
DEST_FILE="puphpet.zip"
DEST_PATH="${DEST_DIR}/${DEST_FILE}"



# Do some sanity check of the current environment.
EXECUTABLES=("curl" "unzip" "git" "${DIR}/bin/formfind.pl")
for EXEC in "${EXECUTABLES[@]}"; do
	if ! command -v "${EXEC}" >/dev/null 2>&1; then
		echo "!! Required command \`${EXEC}\` was not found in PATH. Aborting."
		exit 1
	fi
done


# Scrape the form we need to submit from the source site.
curl -L $SOURCE_URL | "${DIR}/bin/formfind.pl" > "${DEST_DIR}/form.txt"
cat "${DEST_DIR}/form.txt"
exit


# Scrape the ZIP from the source site.
echo "## Starting ZIP file scrape."

if [ ! -d "${DEST_DIR}" ]; then
	echo "## Creating missing destination folder \`${DEST_DIR}\`."
	mkdir -p "${DEST_DIR}"
fi

echo "## Submitted request to \`${DEST_DIR}\`."
curl -L \
 --output "${DEST_PATH}" \
 --data ''\
 $SOURCE_URL

echo "## Done."

#exit 0





# Unpack the zip to our target folder, replacing the existing one if present.
SOURCE_ZIP="${DIR}/tmp/puphpet.zip"

unzip \
 "${SOURCE_ZIP}" \
 -d "${DIR}/unzip"


