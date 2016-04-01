#!/bin/bash
# A command-line script for incrementing build numbers for all known targets in an Xcode project.
#
# This script has two main goals: firstly, to ensure that all the targets in a project have the
# same CFBundleVersion and CFBundleShortVersionString values. This is because mismatched values
# can cause a warning when submitting to the App Store.
#
# Secondly, the script ensures that the build number is incremented when changes are declared
# based on git's records. Alternatively the number of commits can be used, and is toggled by using
# the argument "--reflect-commits". If not on "master", the current branch name will be used to
# ensure no version collisions across branches.
#
# If not using git, you are a braver soul than I.

##
# The xcodeproj. This is usually found by the script, but you may need to specify its location
# if it's not in the same folder as the script is called from (the project root if called as a
# build phase run script).
#
#xcodeproj="Project.xcodeproj"

##
# We have to define an Info.plist as the source of truth. This is typically the one for the main
# target. If not set, the script will try to guess the correct file from the list it gathers from
# the xcodeproj file, but this can be overriden by setting the path here.
#
#plist="Project/Info.plist"

# We use PlistBuddy to handle the Info.plist values. Here we define where it lives.
plistBuddy="/usr/libexec/PlistBuddy"

# Get the xcodeproj if we don't already have it
if [[ -z ${xcodeproj} ]]; then
	xcodeproj=$(find . -depth 1 -name "*.xcodeproj" | sed -e 's/^\.\///g')
	echo "Xcode Project: ${xcodeproj}"
fi

# Find unique references to Info.plist files in the project
projectFile="${xcodeproj}/project.pbxproj"
plists=$(grep "^\s*INFOPLIST_FILE.*$" "${projectFile}" | sed -e 's/^[^"]*"//g' | sed -e 's/"[^"]*$//g' | sort | uniq)

# Attempt to guess the plist based on the list we have
if [[ -z ${plist} ]]; then
	read -r plist <<< "${plists}"
	echo "Source Info.plist: ${plist}"
fi

# Find the current build number in the main Info.plist
mainBundleVersion=$("${plistBuddy}" -c "Print CFBundleVersion" "${plist}")
mainBundleShortVersionString=$("${plistBuddy}" -c "Print CFBundleShortVersionString" "${plist}")
echo "Current project version is ${mainBundleShortVersionString} (${mainBundleVersion})."

# Increment the build number if git says things have changed. Note that we also check the main
# Info.plist file, and if it has already been modified, we don't increment the build number.
# Alternatively, if the script has been called using "--reflect-commits", we just update to the
# current number of commits
git=$(sh /etc/profile; which git)
if [[ -n $1 ]] && [[ $1 == "--reflect-commits" ]]; then
	mainBundleVersion=$("${git}" rev-list --count HEAD)
	branchName=$("${git}" rev-parse --abbrev-ref HEAD)
	if [[ ${branchName} != "master" ]]; then
		mainBundleVersion="${mainBundleVersion}-${branchName}"
	fi
else
	status=$("${git}" status --porcelain)
	if [[ ${#status} != 0 ]] && [[ $status != *"M ${plist}"* ]]; then
		mainBundleVersion=$((${mainBundleVersion} + 1))
	fi
fi

# Update all of the Info.plist files we discovered
while read -r thisPlist; do
	# Find out the current version
	thisBundleVersion=$("${plistBuddy}" -c "Print CFBundleVersion" "${thisPlist}")
	thisBundleShortVersionString=$("${plistBuddy}" -c "Print CFBundleShortVersionString" "${thisPlist}")
	# Update the CFBundleVersion if needed
	if [[ ${thisBundleVersion} != ${mainBundleVersion} ]]; then
		echo "Updating \"${thisPlist}\" with build ${mainBundleVersion}…"
		"${plistBuddy}" -c "Set :CFBundleVersion ${mainBundleVersion}" "${thisPlist}"
	fi
	# Update the CFBundleShortVersionString if needed
	if [[ ${thisBundleShortVersionString} != ${mainBundleShortVersionString} ]]; then
		echo "Updating \"${thisPlist}\" with marketing version ${mainBundleShortVersionString}…"
		"${plistBuddy}" -c "Set :CFBundleShortVersionString ${mainBundleShortVersionString}" "${thisPlist}"
	fi
done <<< "${plists}"