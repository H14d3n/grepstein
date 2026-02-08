#!/usr/bin/env bash

QUERY=$1
PAGE=1
DEPS=(pdftotext jq httpie)
HEADERS=(
	'User-Agent:Mozilla/5.0 (X11; Linux x86_64)'
	'Cookie:justiceGovAgeVerified=true'
)
RED='\e[31m'
YEL='\e[33m'
GRN='\e[32m'
DEF='\e[0m'

dependency_check () {
	echo -e "$YEL \nDependency control... $DEF"
	local dep_status=0
	for i in "${DEPS[@]}"; do
		printf "Checking %s -> " "$i"
		if command -v "$i" &>/dev/null; then echo "passed"; ((dep_status++)); else echo "failed"; fi
	done

	if [[ "$dep_status" -ne "${#DEPS[@]}" ]]; then
		echo -e "$RED\nThere are missing packages. Please install them to use epstein.sh $DEF"
		exit 1
	fi
}

fetch_results () {
	URL="https://www.justice.gov/multimedia-search?keys=$QUERY&page=$PAGE"
	DATA=$(http GET "$URL" "${HEADERS[@]}" | jq)
	TOTAL_RECORDS=$(echo "$DATA" | jq '.hits.total.value')
	PDF_URLS=($(echo "$DATA" | jq -r '.hits.hits[]._source.ORIGIN_FILE_URI' | sed 's/ /%20/g'))
	PDF_COUNT=${#PDF_URLS[@]}

	#echo "$DATA"

	echo -e "$GRN \nWe found $TOTAL_RECORDS result(s) for $QUERY on all pages. Page $PAGE only shows $PDF_COUNT result(s) $DEF"

	if [[ "$PDF_COUNT" -gt 0 ]]; then
		for i in "${!PDF_URLS[@]}"; do
			echo "$i - ${PDF_URLS[i]}"
		done
	fi
}

ask_usrcmd () {
	if [[ "$PDF_COUNT" -gt 0 ]]; then
		echo -e "$GRN \nPlease select your action $DEF"
		echo "-> Type OPEN to open a file"
		echo "-> Type NEXT to continue to next page"
		echo "-> Type EXIT to exit"
		echo -n "Your command : "
		read USRCMD

		if [[ "$USRCMD" == "OPEN" || "$USRCMD" == "open" ]]; then
			echo -ne "$GRN \nPlease write the index number of the file that you want to open : $DEF" 
			read INDEX
			http "${PDF_URLS[INDEX]}" "${HEADERS[@]}" > /tmp/epstein_file.pdf
			pdftotext -layout /tmp/epstein_file.pdf - | less
			rm /tmp/epstein_file.pdf
			fetch_results
			ask_usrcmd
		elif [[ "$USRCMD" == "NEXT" || "$USRCMD" == "next" ]]; then
			echo -e "$YEL \nProceding to next page... $DEF"
			let "PAGE+=1"
			fetch_results
			ask_usrcmd
		elif [[ "$USRCMD" == "EXIT" || "$USRCMD" == "exit" ]]; then
			exit 1
		else
			echo -e "$RED \nInvalid command, please enter a valid command."
			ask_usrcmd	
		fi
	fi
}

dependency_check
fetch_results
ask_usrcmd
