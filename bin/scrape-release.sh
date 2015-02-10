#!/usr/bin/env bash
# Scrapes the latest puphpet.zip file from puphpet.com.
# Usage: `bin/scrape-release.sh` (Run from the project root dir.)



# Disables `git push` when set. Comment out to enable `git push`.
DEBUG=On

DIR="$( cd -P "$( dirname "$0" )"/.. >/dev/null 2>&1 && pwd )"



# Do some sanity check of the current environment.
EXECUTABLES=("curl" "unzip" "git" "${DIR}/bin/git-semver-tags.sh" "${DIR}/bin/semver-increment.sh")
for EXEC in "${EXECUTABLES[@]}"; do
	if ! command -v "${EXEC}" >/dev/null 2>&1; then
		echo "!! Required command \`${EXEC}\` was not found in PATH. Aborting."
		exit 1
	fi
done



# Scrape the ZIP from the source site.
SOURCE_URL="https://puphpet.com"
DEST_DIR="${DIR}/tmp"
DEST_FILE="puphpet.zip"
DEST_PATH="${DEST_DIR}/${DEST_FILE}"

echo "## Starting ZIP file scrape."

if [ ! -d "${DEST_DIR}" ]; then
	echo "## Creating missing destination folder \`${DEST_DIR}\`."
	mkdir -p "${DEST_DIR}"
fi

echo "## Submitting request to \`${SOURCE_URL}\`, saving response to \`${DEST_PATH}\`."
# We only need to POST a non-empty <form> to get the ZIP.
curl -L \
 --silent \
 --output "${DEST_PATH}" \
 --dump-header "${DIR}/tmp/request_headers.txt" \
 --data 'vagrantfile-local[vm][box]=puphpet/debian75-x64' \
 $SOURCE_URL



# Unpack the zip to our target folder, replacing the existing one if present.
SOURCE_ZIP="${DIR}/tmp/puphpet.zip"
TMP_UNZIP_DIR="${DIR}/tmp/unzip"
RELEASE_DIR="${DIR}/release"

if [ -f "${SOURCE_ZIP}" ]; then
	echo "## Removing existing destination dir \`${TMP_UNZIP_DIR}\`."
	rm -rf "${TMP_UNZIP_DIR}"
fi

echo "## Extracting temp archive \`${SOURCE_ZIP}\` to \`${TMP_UNZIP_DIR}\`."
unzip \
 -oqq \
 "${SOURCE_ZIP}" \
 -d "${TMP_UNZIP_DIR}"

# Get the random folder name inside the extracted folder.
RANDOM_SUB_DIR=$(cd -P "${TMP_UNZIP_DIR}" >/dev/null 2>&1; echo *)

if [ -d "${RELEASE_DIR}" ]; then
	echo "## Removing existing release dir \`${RELEASE_DIR}\`."
	rm -rf "${RELEASE_DIR}"
fi

echo "## Staging release into \`${RELEASE_DIR}\`."
mv -f "${TMP_UNZIP_DIR}/${RANDOM_SUB_DIR}" "${RELEASE_DIR}"



# Commit any and all changes to the release/ folder back into git.
# Use available local information to tag the commit for future identification.
GIT_COMMIT_MSG="Auto-release. `date`."
GIT_ACTIVE_BRANCH=$(git rev-parse --quiet --abbrev-ref HEAD 2>/dev/null)
#@TODO: Might want to eventually limit the "last semver" checking to a specific major release number so the auto updater wouldn't "pile on" if we started a new version ourselves. See Shell-Scripts' `semver-get-pointrelease` for sed command.
GIT_LAST_SEMVER=$("${DIR}/bin/git-semver-tags.sh" | head -1)
GIT_NEXT_SEMVER=$("${DIR}/bin/semver-increment.sh" -m $GIT_LAST_SEMVER)
GIT_REMOTE_NAME="origin"

# Check for changes to the release/ directory that would need to
# be committed to git. Bail out if there aren't any.
LOCAL_CHANGES=$(git status --porcelain `basename "${RELEASE_DIR}/"`)
if [ -z "$LOCAL_CHANGES" ]; then
	echo "## There are no upstream changes to the puphpet release. Exiting."
	exit 0
fi

echo "## Committing the updated release to git."
git add -A "${RELEASE_DIR}" 2>/dev/null
git commit -m "${GIT_COMMIT_MSG}"

echo "## Creating a new semver tag \`${GIT_NEXT_SEMVER}\`."
git tag -a $GIT_NEXT_SEMVER -m "${GIT_COMMIT_MSG}"

echo "## Pushing commit and tag to origin."
GIT_DRY_RUN="--dry-run"
if [ -z "${DEBUG}" ]; then
	GIT_DRY_RUN=""
fi
git push $GIT_DRY_RUN $GIT_REMOTE_NAME $GIT_ACTIVE_BRANCH
git push $GIT_DRY_RUN $GIT_REMOTE_NAME $GIT_NEXT_SEMVER


echo "## Done."
