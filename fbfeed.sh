#!/bin/bash

groups_id=290068101326664
version=2.3
limit=100
access_token=$1
since_date=$( date '+%Y-%m-%d' )
until_date=$( date --date='+ 1 day' '+%Y-%m-%d' )
path_groups='conf/groups-empregos-campos-dos-goytacazes'

function browser
{
	printf "Opening browser"
	sensible-browser "https://developers.facebook.com/tools/explorer/?&version=v2.3" > /dev/null
	printf "\ec"
}

function groups_choice
{
	# Show Files
	printf "\ec"

	indice_file=0
	for i in $(ls conf | grep 'groups'); do
		indice_file=$(expr $indice_file + 1)
		
		echo "$indice_file - $i";
	done;

	# Print question
	printf "Choice your groups[1..$indice_file]: "
	read choice_group

	# Save choice in file .group
	indice_file=0
	for i in $(ls conf | grep groups); do
		indice_file=$(expr $indice_file + 1)
		
		if [ "$indice_file" == "$choice_group" ]; then
			#echo "conf/$i" > conf/.group
			path_groups="conf/$i"
		fi		
	done;

	printf "\ec"	
}

function since_until_date
{
	since_date=''
	until_date=''

	# Print question date
	printf "\ecChoice your since date[YYYY-MM-DD]: "
	read choice_since

	printf "Choice your until date[YYYY-MM-DD]: "
	read choice_until
	
	# Save date
	since_date=$choice_since
	until_date=$choice_until

	printf "\ec"	
}

function token
{
	# Manipulando access_token
	if [ "$access_token" != '' ]; then 
		echo $access_token > conf/.access_token

	elif [ -z $1 ] && [ -e 'conf/.access_token' ]; then 
		access_token=$(cat conf/.access_token)

	else
		touch conf/.access_token
	
		echo "Token de acesso: "
		read access_token
		echo $access_token > conf/.access_token

		echo "File conf/.access_token create success"	
	fi

	printf "\ec"	
}

function validade
{
	
	token
	validade_permission=false
	
	# Validade token
	while [[ $validade_permission = false ]]; do
			

			# Get Content
			content=$( curl -s -X GET "https://graph.facebook.com/v{$version}/{$groups_id}/feed?access_token={$access_token}&limit={$limit}&fields=id,message,picture,actions" )
			error_code=$( echo $content | jq -r ".error.code" )

			if [ "$error_code" == "190" ]; then
				browser

				printf "\nToken Expirado\n"
				

				printf "Requisitando um novo token:\n"
				read access_token	

				if [[ "${#access_token}" < 100 ]]; then
					printf "Token Deve conter mais de 100 caracteres:\n"
					read access_token

					validade_permission=true
				fi

				if [[ -z $access_token ]]; then
					printf "Token Vazio:\n"
					read access_token

					validade_permission=true
				fi

				#validade_permission=false

			else
				printf "\nToken Valido\n"

				echo $access_token > conf/.access_token

				validade_permission=true
				break				
			fi
			
	done

	printf "\ec"
}

function groups_add
{
	content=$( curl -s -X GET "https://graph.facebook.com/v{$version}/search?q={$1}&type=group&access_token={$access_token}" )

	id=$( echo $content | jq -r '.data[0].id' )
	name=$( echo $content | jq -r '.data[0].name' )
	
	echo $id >> $path_groups

	printf "\nID: $id"
	printf "\nGroup: $name \nadicionado com sucesso\n"
	printf "\ec"
}

function groups_list
{
	# Total 
	total=$(wc -l $path_groups | awk '{print $1}')
	indice=1

	echo '' > "feed/txt/groups_list.txt"

	for groups_id in $( cat $path_groups ); do

		content=$( curl -s -X GET "https://graph.facebook.com/v{$version}/{$groups_id}/?fields=id,name,description,icon&access_token={$access_token}" )
		
		id=$( echo $content | jq -r '.id' )
		name=$( echo $content | jq -r '.name' )
		description=$( echo $content | jq -r '.description' )

		# Content
		content="\n\nid: %s\nName: %s\nhttps://www.facebook.com/groups/%s/\n\nDescription: %s\n======================================================\n"

		printf "$content" \
		"$id" \
		"$name" \
		"$id" \
		"$description" >> "feed/txt/groups_list.txt"

		porcentagem=$(( (100 * $indice ) / $total ))
		printf "\ec#%s%% - %s-%s\n" "$porcentagem" "$indice" "$total" 

		# inscrement
		indice=$(expr $indice + 1)

	done 
	printf "\ec"
}

function groups_list_html
{
	groups_result_html='feed/html/groups_list.html'

	# Header
	head_html=$( cat assets/head )
	echo $head_html > $groups_result_html

	# Total 
	total=$(wc -l $path_groups | awk '{print $1}')
	indice=1
	
	echo

	for groups_id in $( cat $path_groups ); do

		content=$( curl -s -X GET "https://graph.facebook.com/v{$version}/{$groups_id}/?fields=id,name,description,icon&access_token={$access_token}" )
		
		id=$( echo $content | jq -r '.id' )
		name=$( echo $content | jq -r '.name' )
		icon=$( echo $content | jq -r '.icon' )
		description=$( echo $content | jq -r '.description' )
		

		# Content
		content_html=$( cat assets/content_groups_list )

		printf "$content_html" \
		"$icon" \
		"$name" \
		"$description" \
		"$id" \
		"$id" >> $groups_result_html 

		porcentagem=$(( (100 * $indice ) / $total ))
		printf "#Indice: %s-%s #%s%%\n" "$indice" "$total" "$porcentagem"

		# inscrement
		indice=$(expr $indice + 1)
	done 

	echo
	# Footer
	footer_html=$( cat assets/footer )
	echo $footer_html >> $groups_result_html

	printf "\ec"
}

function download
{
	total=$(wc -l $path_groups | awk '{print $1}')
	indice=1
		
	# Clear old files and create directory
	rm -f data_groups/${path_groups:5:15}/* 
	mkdir data_groups/${path_groups:5:15} 2> /dev/null
	
	# Build Url
	url="https://graph.facebook.com"
	fields1="access_token=$access_token"
	fields2="limit=$limit"
	fields3="since=$since_date"
	fields4="until=$until_date"
	fields5="fields=id,message,full_picture,actions,created_time"
	querystring="$fields1&$fields2&$fields3&$fields4&$fields5"

	for groups_id in $( cat $path_groups ); do
		
		porcentagem=$(( (100 * $indice) / $total ))

		
		full_url="$url/v$version/$groups_id/feed?$querystring"
		# Current File
		current_file="data_groups/${path_groups:5:15}/$groups_id"

		printf "\ec#ID: %s: #Indice: %s-%s #%s%%\n" \
		"$groups_id" \
		"$indice" \
		"$total" \
		"$porcentagem"

		# Download file
		curl \
		--progress-bar \
		-X GET \
		"$full_url" > $current_file

		# inscrement		
		indice=$(expr $indice + 1)

	done 

	printf "\ec"
}

function search_groups
{
	#path_groups=$(cat conf/.group)
	groups_list=$( ls "data_groups/${path_groups:5:15}" | awk '{print $1}') 
	groups_total=$( ls -1 "data_groups/${path_groups:5:15}" | wc -l )
	indice_file=0

	echo '' > "feed/txt/groups_result.txt"
	content="id: %s\nMessage: %s\nlink: %s\n\ncreated_time: %s\nupdated_time: %s\n======================================================\n\n"

	# Benchmarck - Start
	start=$(date '+%s')

	for groups_id in $groups_list; do 
			
			# Current File
			current_file="data_groups/${path_groups:5:15}/$groups_id"

		for i in $(seq 1 $limit); do 

			# Current post
			cat $current_file | jq -r ".data[$i]" > current_file.json

			# Continue if json is empty
			validade_file=$( cat current_file.json| jq -r "." )
			
			if [ "$validade_file" = "null" ]; then
				continue
			fi

			id=$( cat current_file.json | jq -r ".id" 2> /dev/null )
			message=$( cat current_file.json | jq -r ".message" 2> /dev/null )
			link=$( cat current_file.json | jq -r ".actions[0].link" 2> /dev/null )
			created_time=$( cat current_file.json | jq -r ".created_time" 2> /dev/null )
			updated_time=$( cat current_file.json | jq -r ".updated_time" 2> /dev/null )

			# arg - Search
			search=$( echo $message | grep -E -i "$1" )
			
			if [ "$search" ] && [ "$message" != "null" ]; then

				created_time=$( date --date="$created_time" '+%d/%m/%Y - %H:%M:%S' )
				updated_time=$( date --date="$updated_time" '+%d/%m/%Y - %H:%M:%S' )
			

				# Save result in file
				printf "$content" \
				"$id" \
				"$message" \
				"$link" \
				"$created_time" \
				"$updated_time" >> "feed/txt/groups_result.txt"
			fi

			# Show progress
			porcentagem=$(( ( 100 * $i ) / $limit ))
			porcentagem_file=$(( ( 100 * $indice_file ) / $groups_total ))			
			
			printf "\ec#%s%%  %s-%s\n#%s%%  %s\n" \
			$porcentagem \
			$i \
			$limit \
			$porcentagem_file \
			$id
		done

		# increment
		indice_file=$(expr $indice_file + 1)
	done

	# Benchmarck - End
	end=$( date '+%s')
	# Benchmarck - Result
	runtime=$(( end-start ))
	printf " \ecBenchmarck - $runtime \n\n"

	rm current_file.json
}

function search_groups_html
{
	# feed/md/2017-01-14-campos-dos-goytacazes.md
	current_date=$( date '+%Y-%m-%d' )
	groups_result_md="feed/md/$current_date-${path_groups:21}.md"

	groups_list=$( ls -1 "data_groups/${path_groups:5:15}" ) 
	groups_total=$( ls -1 "data_groups/${path_groups:5:15}" | wc -l )
	indice_file=0

	# Header
	head_md="\u002D\u002D\u002D\nlayout: post\ntitle: \"%s\"\ndate: %s\ncomments: true\ntag: %s\n\u002D\u002D\u002D\n"
	
	title=${path_groups:21}

	
	printf "$head_md" \
	"$current_date ${title//'-'/' '}" \
	"$current_date" \
	"${path_groups:21}" > $groups_result_md
	
	# Benchmarck - Start
	start=$(date '+%s')

	for groups_id in $groups_list; do 
		
		# Current File
		current_file="data_groups/${path_groups:5:15}/$groups_id"

		for i in $(seq 1 $limit); do 


			# Current post
			cat $current_file | jq -r ".data[$i]" > current_file.json
			
			# Continue if json is empty
			validade_file=$( cat current_file.json| jq -r "." )
			
			if [ "$validade_file" = "null" ]; then
				continue
			fi

			id=$( cat current_file.json | jq -r ".id" 2> /dev/null )
			message=$( cat current_file.json | jq -r ".message" 2> /dev/null )
			full_picture=$( cat current_file.json | jq -r ".full_picture" 2> /dev/null )
			link=$( cat current_file.json | jq -r ".actions[0].link" 2> /dev/null )
			created_time=$( cat current_file.json | jq -r ".created_time" 2> /dev/null )
			updated_time=$( cat current_file.json | jq -r ".updated_time" 2> /dev/null )

			# arg - Search
			search=$( echo $message | grep -E -i "$1" )
			
			if [ "$search" ] && [ "$message" != "null" ]; then

				# Convert Date
				created_time=$( date --date="$created_time" '+%d/%m/%Y - %H:%M:%S' )
				updated_time=$( date --date="$updated_time" '+%d/%m/%Y - %H:%M:%S' )

				# Com imagem
				if [ "$full_picture" != "null" ];then

					# Content
					content_md="### %s\n![%s](%s){:height=\"476px\" width=\"550px\"}\n\n%s\n\n###### %s\n\n###### %s\n[%s](%s)\n\n\n"

					printf "$content_md" \
					"${id:16}" \
					"$id" \
					"$full_picture" \
					"$message" \
					"$created_time" \
					"$updated_time" \
					"$id" \
					"$link" >> $groups_result_md
				else
					
					# Content
					content_md="### %s\n%s\n\n###### %s\n\n###### %s\n[%s](%s)\n\n\n"

					printf "$content_md" \
					"${id:16}" \
					"$message" \
					"$created_time" \
					"$updated_time" \
					"$id" \
					"$link" >> $groups_result_md
				fi
	
			fi	

			# Show progress
			porcentagem=$(( ( 100 * $i ) / $limit ))
			porcentagem_file=$(( ( 100 * $indice_file ) / $groups_total ))			
		
			printf "#%s%%  %s-%s\n#%s%%  %s\n" \
			$porcentagem \
			$i \
			$limit \
			$porcentagem_file \
			$id

		done

		# increment
		indice_file=$(expr $indice_file + 1)
		
	done

	# Footer
	footer_html=$( cat assets/footer )
	echo $footer_html >> $groups_result_html

	# Benchmarck - End
	end=$( date '+%s')
	# Benchmarck - Result
	runtime=$(( end-start ))
	printf " \ecBenchmarck - $runtime \n\n"

	rm current_file.json
}

validade

## Menu
while :
do

	cat <<-EOF
		Dafult:
		---------------------------
		Since Date  - $since_date
		Until Date  - $until_date
		Limit       - $limit
		AccessToken - ${access_token:0:5}...
		Path ids    - ${path_groups:21}
		---------------------------
		
		Options:
		[t]   -   Get Token
		[g]   - Ids - groups
		[sd]  - Since Date
		[l]   - Limit (50)
		[d]   - Download
		---   - ---	
		[s]   - Txt Search
		[sf]  - Txt Search file
		---   - ---
		[h]   - Html Search
		[hf]  - Html Search file
		---   - ---
		[a]   - Add group
		[gl]  - List groups
		[glh] - List groups html
		---   - ---
		[c]   - Clear
		[q]   - Quit
	EOF
	
	read menu

	case $menu in
		'd') download;;

		'g') groups_choice;;

		'sd') since_until_date ;;

		't') browser;;

		'l')
			printf "\ec"
			echo "New limit: "
			read limit
			download
			;;

		'h')
			printf "\ec"
			echo "Search: "
			read query

			search_groups_html $query
			;;

		'hf') 
			terms=$( cat conf/search | sed -e ':a;N;$!ba;s/\n/|/g' )
			search_groups_html $terms
			;;
			

		's') 
			printf "\ec"
			echo "Search: "
			read query

			search_groups $query
			;;
			
		'sf')
			terms=$( cat conf/search | sed -e ':a;N;$!ba;s/\n/|/g' )
			search_groups "$terms"
			;;

		'a')
			printf "\ec"
			echo "Name: "
			read name

			groups_add $name
			;;

		'gl') groups_list;;

		'glh') groups_list_html;;

		'c') clear;;

		'q') echo "Bye!";exit;;
	esac
done