#!/bin/sh
# This script analyse the git project in the current workspace ${GITHUB_WORKSPACE}
# It executes phpcs and phpcbf if error were found on the modified files of the last commit.

echo GITHUB_HEAD_REF=${GITHUB_HEAD_REF}
echo GITHUB_BASE_REF=${GITHUB_BASE_REF}
echo INPUT_PHPCS_HEAD_REF=${INPUT_PHPCS_HEAD_REF}
echo INPUT_PHPCS_BASE_REF=${INPUT_PHPCS_BASE_REF}

if [ -n "${GITHUB_WORKSPACE}" ]; then
  cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit
  git config --global --add safe.directory "${GITHUB_WORKSPACE}" || exit 1
fi

/usr/local/bin/phpcs.phar --config-set installed_paths /tmp/rulesets

run_phpcs() {
  if [ "${INPUT_USE_DEFAULT_CONFIGURATION_FILE}" = true ]; then
    /usr/local/bin/phpcs.phar \
      --report-checkstyle \
      -n -s -p -d memory_limit=-1 --parallel=2 --extensions=php --colors --tab-width=4 --encoding=utf-8 --runtime-set ignore_warnings_on_exit true ${STAGED_FILES_CMD}
  else
    /usr/local/bin/phpcs.phar \
      --report-checkstyle \
      --standard="${INPUT_PHPCS_STANDARD}" \
      -n -s -p -d memory_limit=-1 --parallel=2 --extensions=php --colors --tab-width=4 --encoding=utf-8 --runtime-set ignore_warnings_on_exit true ${STAGED_FILES_CMD}
  fi
}

run_phpcbf() {
  if [ "${INPUT_USE_DEFAULT_CONFIGURATION_FILE}" = true ]; then
    /usr/local/bin/phpcbf.phar \
      -n -s -p -d memory_limit=-1 --parallel=2 --extensions=php --colors --tab-width=4 --encoding=utf-8 --runtime-set ignore_warnings_on_exit true ${STAGED_FILES_CMD}
  else
    /usr/local/bin/phpcbf.phar \
      --standard="${INPUT_PHPCS_STANDARD}" \
      -n -s -p -d memory_limit=-1 --parallel=2 --extensions=php --colors --tab-width=4 --encoding=utf-8 --runtime-set ignore_warnings_on_exit true ${STAGED_FILES_CMD}
  fi
}


# Main

# Get the list of all files modified by the last commit
echo "Get list of files modified by the last commit..."
git log -n 5 --decorate
git diff-tree --no-commit-id --name-only -r HEAD
export STAGED_FILES_CMD=`git diff-tree --no-commit-id --name-only -r HEAD`
echo $STAGED_FILES_CMD

if [ "$FILES" != "" ]
then
    echo "Running PHPCS Code Sniffer..."

    run_phpcs

    # get status code of command
    # 0 = success
    # phpcs 2 = fixable errors found
    # phpcs 1 = only not fixable errors found

    RESULT=$?
    echo "exit code = ${RESULT}"
    if [ "${RESULT}" -ne 0 ]; then
      echo "phpcs failed with status code: ${RESULT}"

      #if result is 1, then only not fixable errors found
      if [ "${RESULT}" -eq 1 ]; then
        echo "only not fixable errors found"
        exit 1
      fi

      #if result is 2, then fixable errors found
      if [ "${RESULT}" -eq 2 ]; then
        echo "fixable errors found (2)"
        echo "Running phpcbf"
        run_phpcbf

        # rerun phpcs
        run_phpcs

        SECOND_PHPCS_RESULT=$?

        echo "Second phpcs result = ${SECOND_PHPCS_RESULT}"

        if [ "${SECOND_PHPCS_RESULT}" -eq 1 ]; then
          echo "phpcbf failed to fix all errors"
          exit 1
        fi

        # if second phpcs result is 0, then no errors found
        if [ "${SECOND_PHPCS_RESULT}" -eq 0 ]; then
          echo "Success, no errors found"
          exit 0
        fi

        exit "${SECOND_PHPCS_RESULT}"
       fi

    fi
else
    echo No modified file found
fi
