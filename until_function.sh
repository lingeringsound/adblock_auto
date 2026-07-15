#!/bin/sh
export PATH="`pwd`:${PATH}"

#移除Adguard_Chinese的秋风规则
function remove_AWAvenue_Ads_Rule_Filter(){
local file="${1}"
test ! -f "${file}" && return
busybox sed -i "/AWAvenue Ads Rule/,/^$/d" "${file}"
}

#下载Adblock规则
function download_link(){
local IFS=$'\n'

target_dir="${1}"
test "${target_dir}" = "" && target_dir="`pwd`/temple/download_Rules"
mkdir -p "${target_dir}"

list='
https://easylist-downloads.adblockplus.org/antiadblockfilters.txt|antiadblockfilters.txt
https://easylist-downloads.adblockplus.org/easylist.txt|easylist.txt
https://easylist-downloads.adblockplus.org/easylistchina.txt|easylistchina.txt
https://raw.githubusercontent.com/easylist/easylist/refs/heads/master/easylist/easylist_adservers_popup.txt|easylist_adservers_popup.txt
https://filters.adtidy.org/android/filters/15_optimized.txt|adguard_optimized.txt
https://filters.adtidy.org/extension/ublock/filters/224.txt|Adguard_Chinese.txt
https://filters.adtidy.org/extension/ublock/filters/11.txt|Adguard_mobile.txt
https://filters.adtidy.org/extension/ublock/filters/2_optimized.txt|AdGuard_Base_filter_dns.txt
'

for i in ${list}
do
test "$(echo "${i}" | grep -E '^#' )" && continue
	name=`echo "${i}" | cut -d '|' -f2`
		URL=`echo "${i}" | cut -d '|' -f1`
	test ! -f "${target_dir}/${name}" && curl -k -L -o "${target_dir}/${name}" "${URL}" >/dev/null 2>&1 && echo "※ `date +'%F %T'` ${name} 下载成功！"
busybox sed -i 's/\\n/换行符正则表达式nn/g' "${target_dir}/${name}"
test "${name}" = "Adguard_Chinese.txt" && remove_AWAvenue_Ads_Rule_Filter "${target_dir}/${name}"
dos2unix "${target_dir}/${name}" >/dev/null 2>&1
done
}

#写入基本信息
function write_head(){
local file="${1}"
local Description="${3}"
test "${Description}" = "" && Description="${2}"
local count=`cat "${file}" | busybox sed '/^!/d;/^[[:space:]]*$/d' | wc -l ` 
local original_file=`cat "${file}"`
cat << key > "${file}"
[Adblock Plus 2.0]
! Title: ${2}
! Version: `date +'%Y%m%d%H%M%S'`
! Expires: 12 hours (update frequency)
! Last modified: `date +'%F %T'`
! Total Count: ${count}
! Blocked Filters: ${count}
! Description: ${Description}
! Homepage: https://lingeringsound.github.io/adblock_auto
! GitHub Homepage: https://github.com/lingeringsound/adblock_auto
! Gitlink Homepage: https://www.gitlink.org.cn/keytoolazy/adblock_auto
! Github Raw Link: https://lingeringsound.github.io/adblock_auto/Rules/${file##*/}
! Gitlink Raw Link: https://cdn09022024.gitlink.org.cn/api/v1/repos/keytoolazy/adblock_auto/raw/Rules/${file##*/}?ref=main&access_token=9aa2be1250ca725d0ef1b1f638fb3de408a11335
! Github Raw CDN Link: https://cdn.jsdelivr.net/gh/lingeringsound/adblock_auto@main/Rules/${file##*/}

key
echo "${original_file}" >> "${file}"
busybox sed -i 's/换行符正则表达式n/\\/g' "${file}"
perl "`pwd`/addchecksum.pl" "${file}"
}

#净化规则
function modtify_adblock_original_file() {
local file="${1}"
if test "${2}" = "" ;then
	busybox sed -i 's/\\n/换行符正则表达式nn/g' "${file}"
	local new=`cat "${file}" | iconv -t 'utf8' | grep -Ev '^#\@\?#|^\$\@\$|^#\%#|^#\@\%#|^#\@\$\?#|^#\$\?#|^<<|<<1023<<' | busybox sed 's|^[[:space:]]@@|@@|g' | sort | uniq | busybox sed '/^!/d;/^[[:space:]]*$/d;/^\[.*\]$/d' `
	echo "$new" > "${file}"
else
	busybox sed -i 's/\\n/换行符正则表达式nn/g' "${file}"
	local new=`cat "${file}" | iconv -t 'utf8' | grep -Ev '^#\@\?#|^\$\@\$|^#\%#|^#\@\%#|^#\@\$\?#|^#\$\?#|^<<|<<1023<<' | grep -Ev "${2}" | busybox sed 's|^[[:space:]]@@|@@|g' | sort | uniq | busybox sed '/^!/d;/^[[:space:]]*$/d;/^\[.*\]$/d' `
	echo "$new" > "${file}"
fi

}

function make_white_rules(){
local file="${1}"
local IFS=$'\n'
local white_list_file="${2}"
for o in `cat "${white_list_file}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' `
do
busybox sed -i -E "/${o}/d" "${file}"
done
}

function fix_Rules(){
local file="${1}"
local target_content="${2}"
local fix_content="${3}"
test ! -f "${file}" -o "${fix_content}" = "" && return 
busybox sed -i "s|${target_content}|${fix_content}|g" "${file}"
}

function Combine_adblock_original_file(){
local file="${1}"
local target_folder="${2}"
test "${target_folder}" = "" && echo "※`date +'%F %T'` 请指定合并目录……" && exit
for i in "${target_folder}"/*.txt
do
	dos2unix "${i}" >/dev/null 2>&1
	echo "`cat "${i}"`" >> "${file}"
done
}

#筛选整理规则
function wipe_white_list() {
	local file="${2}"
	local output_folder="${1}"
	if test -f "${file}" ;then
	local IFS=$'\n'
	local new=$(cat "${file}" | grep -Ev "${3}" | sort | uniq | busybox sed '/^!/d;/^[[:space:]]*$/d' )
		mkdir -p "${output_folder}"
		echo "$new" > "${output_folder}/${file##*/}"
	fi
}

function sort_web_rules() {
	local file="${2}"
	local output_folder="${1}"
	if test -f "${file}" ;then
	local IFS=$'\n'
	local new=$(cat "${file}" | grep -Ev '^\@\@|^[[:space:]]\@\@\|\||^<<|<<1023<<|^\@\@\|\||^\|\||^##|^###|^\/|\/ad\/|^:\/\/|^_|^\?|^\.|^-|^=|^:|^~|^,|^&|^#\$#|#\@#|^\$|^\||^\*|^#\%#' | sort | uniq | busybox sed '/^!/d;/^[[:space:]]*$/d' )
		mkdir -p "${output_folder}"
		echo "$new" >> "${output_folder}/${file##*/}"
	fi
}

function sort_adblock_Rules() {
	local file="${2}"
	local output_folder="${1}"
	if test -f "${file}" ;then
		local IFS=$'\n'
		local new=$(cat "${file}" | grep -E "${3}" | sort | uniq | busybox sed '/^!/d;/^[[:space:]]*$/d' )
			mkdir -p "${output_folder}"
		echo "$new" > "${output_folder}/${file##*/}"
	fi
}

function add_rules_file() {
	local file="${2}"
	local output_folder="${1}"
	local IFS=$'\n'
	local new=$(cat "${file}" | grep -E "${3}" | sort | uniq | busybox sed '/^!/d;/^[[:space:]]*$/d' )
	if test -f "${output_folder}/${file##*/}" ;then
		mkdir -p "${output_folder}"
				echo "$new" >> "${output_folder}/${file##*/}"
			local sort_file=`cat "${output_folder}/${file##*/}" | sort | uniq | busybox sed '/^!/d;/^[[:space:]]*$/d' `
		echo "${sort_file}" > "${output_folder}/${file##*/}"
	fi
}

#测试github 加速的链接
function Get_Download_github_raw_link(){
local download_target="${1}"
if test "`ping -c 1 -W 3 raw.fgit.ml >/dev/null 2>&1 && echo 'yes'`" = "yes" ;then
	target="`echo ${download_target} | sed 's|raw.githubusercontent.com|raw.fgit.ml|g'`"
elif test "`ping -c 1 -W 3 ghproxy.com >/dev/null 2>&1 && echo 'yes'`" = "yes" ;then
	target="https://ghproxy.com/${download_target}"
elif test "`ping -c 1 -W 3 raw.gitmirror.com >/dev/null 2>&1 && echo 'yes'`" = "yes" ;then
	target="`echo ${download_target} | sed 's|raw.githubusercontent.com|raw.gitmirror.com|g'`"
elif test "`ping -c 1 -W 3 raw.iqiq.io >/dev/null 2>&1 && echo 'yes'`" = "yes" ;then
	target="`echo ${download_target} | sed 's|raw.githubusercontent.com|raw.iqiq.io|g'`"
elif test "`ping -c 1 -W 3 raw.fastgit.org >/dev/null 2>&1 && echo 'yes'`" = "yes" ;then
	target="`echo ${download_target} | sed 's|raw.githubusercontent.com|raw.fastgit.org|g'`"
else
	echo "${download_target}" | grep -q 'raw.githubusercontent.com' && echo "[E]`date +'%F %T'` 错误！无法连接网络！" && exit 1
fi
	echo "${target}"
}

#shell 特殊字符转义
function escape_special_chars(){
	local input=${1}
	local output=$(echo ${input} | busybox sed 's/[\^\|\*\?\$\=\@\/\.\"\+\;\(\)\{\}]/\\&/g;s|\[|\\&|g;s|\]|\\&|g' )
	echo ${output}
}

#去除指定重复的Css
function sort_Css_Combine(){
local IFS=$'\n'
local target_file="${1}"
local target_file_tmp="`pwd`/${target_file##*/}.tmp"
local target_output_file="`pwd`/${target_file##*/}.temple"
local count_Rules_all=`cat "${target_file}" | grep '#'  | busybox sed '/^#/d;/^!/d;/^\|\|/d;/^\//d' | busybox sed -E 's/.*\.[A-Za-z]{2,8}#{1,1}//g' | sort | uniq -d | wc -l`
local a=0
busybox sed -i 's/\\n/换行符正则表达式nn/g' "${target_file}"
local new_file=$(cat "${target_file}" | iconv -t 'utf-8' | sort -u | uniq | busybox sed '/^!/d;/^[[:space:]]*$/d;/^\[.*\]$/d' )
echo "${new_file}" > "${target_file}"
for target_content in `cat "${target_file}" | grep '#'  | busybox sed '/^#/d;/^!/d;/^\|\|/d;/^\//d' | busybox sed -E 's/.*\.[A-Za-z]{2,8}#{1,1}//g' | sort | uniq -d `
do
a=$(($a + 1))
target_content="#${target_content}"
transfer_content=$(escape_special_chars ${target_content})
grep -E "${transfer_content}$" "${target_file}" > "${target_file_tmp}" && echo "※处理重复Css规则( $count_Rules_all → $(($count_Rules_all - ${a})) ): ${transfer_content}$"
if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed 's|#.*||g' | grep -E ',')" != "" ;then
	busybox sed -i 's|#.*||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | tr ',' '\n' | busybox sed '/^[[:space:]]*$/d' | sort  | uniq )
	echo "${before_tmp}" > "${target_file_tmp}"
	busybox sed -i ":a;N;\$!ba;s#\n#,#g" "${target_file_tmp}"
	if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' )" != "" ;then 
		grep -Ev "${transfer_content}$" "${target_file}" >> "${target_output_file}" 
cat << key >> "${target_output_file}" 
`cat "${target_file_tmp}"`${target_content}
key
		mv -f "${target_output_file}" "${target_file}"
	fi
else
	busybox sed -i 's|#.*||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | busybox sed '/^[[:space:]]*$/d' | sort | uniq)
	echo "${before_tmp}" > "${target_file_tmp}"
	if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' | wc -l)" -gt "1" ;then
		busybox sed -i ":a;N;\$!ba;s#\n#,#g" "${target_file_tmp}"
	fi
	if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' )" != "" ;then 
		grep -Ev "${transfer_content}$" "${target_file}" >> "${target_output_file}" 
cat << key >> "${target_output_file}" 
`cat "${target_file_tmp}"`${target_content}
key
		mv -f "${target_output_file}" "${target_file}"
	fi
fi
done
rm -rf "${target_file_tmp}" 2>/dev/null
}

#去除重复作用的域名
function sort_domain_Combine(){
local IFS=$'\n'
local target_file="${1}"
local target_file_tmp="`pwd`/${target_file##*/}.tmp"
local target_output_file="`pwd`/${target_file##*/}.temple"
local count_Rules_all=`cat "${target_file}" | busybox sed 's|domain=.*||g' | sort | uniq -d | busybox sed '/^[[:space:]]*$/d' | wc -l `
local a=0
busybox sed -i 's/\\n/换行符正则表达式nn/g' "${target_file}"
local new_file=$(cat "${target_file}" | iconv -t 'utf-8' | sort -u | uniq | busybox sed '/^!/d;/^[[:space:]]*$/d;/^\[.*\]$/d' )
echo "${new_file}" > "${target_file}"
for target_content in `cat "${target_file}" | grep 'domain=' | busybox sed 's|domain=.*||g' | sort | uniq -d | busybox sed '/^[[:space:]]*$/d' `
do
a=$(($a + 1))
target_content="${target_content}domain="
transfer_content=$(escape_special_chars ${target_content} )
grep -E "^${transfer_content}" "${target_file}" > "${target_file_tmp}" && echo "※处理重复作用域名规则( $count_Rules_all → $(($count_Rules_all - ${a} )) ): ^${transfer_content}"
if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed 's|.*domain=||g' | grep -E ',' )" != "" ;then
	echo "※规则 ${target_content} 包含其他限定器！"
	local fixed_tmp=$(cat "${target_file_tmp}" | busybox sed 's/[[:space:]]$//g' | grep -Ev ',(important|third-party|script|media|subdocument|document|xmlhttprequest|other|stealth|image|stylesheet|content|match-case|font|sitekey|popup|xhr|object|generichide|genericblock|elemhide|all|badfilter|websocket|~important|~third-party|~script|~media|~subdocument|~document|~xmlhttprequest|~other|~stealth|~image|~stylesheet|~content|~match-case|~font|~sitekey|~popup|~xhr|~object|~generichide|~genericblock|~elemhide|~all|~badfilter|~websocket)$' | busybox sed '/^[[:space:]]*$/d' | sort | uniq)
	echo "${fixed_tmp}" > "${target_file_tmp}"
	echo "※尝试修复中……"
	local Rules_juggle=`cat "${target_file_tmp}" | sort | uniq | busybox sed '/^[[:space:]]*$/d' | wc -l`
	test "${Rules_juggle}" -le "1" && echo "※无法合并，已跳过！" && continue
fi
if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed 's|.*domain=||g' | grep -E '\|')" != "" ;then
	busybox sed -i 's|.*domain=||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | tr '|' '\n' | busybox sed '/^[[:space:]]*$/d' | sort  | uniq)
	echo "${before_tmp}" > "${target_file_tmp}"
	busybox sed -i ":a;N;\$!ba;s#\n#\|#g" "${target_file_tmp}"
	if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' )" != "" ;then 
		grep -Ev "^${transfer_content}" "${target_file}" >> "${target_output_file}" 
cat << key >> "${target_output_file}" 
${target_content}`cat "${target_file_tmp}"`
key
		mv -f "${target_output_file}" "${target_file}"
	fi
else
	busybox sed -i 's|.*domain=||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | busybox sed '/^[[:space:]]*$/d' | sort  | uniq)
	echo "${before_tmp}" > "${target_file_tmp}"
	if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' | wc -l)" -gt "1" ;then
		busybox sed -i ":a;N;\$!ba;s#\n#\|#g" "${target_file_tmp}"
	fi
	if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' )" != "" ;then 
		grep -Ev "^${transfer_content}" "${target_file}" >> "${target_output_file}"
cat << key >> "${target_output_file}" 
${target_content}`cat "${target_file_tmp}"`
key
		mv -f "${target_output_file}" "${target_file}"
	fi
fi
done
rm -rf "${target_file_tmp}" 2>/dev/null
busybox sed -i 's/换行符正则表达式n/\\/g' "${target_file}"
}


#去重函数python版
function sort_Css_Combine_python() {
local target_file="${1}"
local python_file="`pwd`/Adblock_sort.py"
if [ -f "$target_file" ] && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "css" "$target_file"
else
	sort_Css_Combine "$target_file"
fi
}

function sort_domain_Combine_python() {
local target_file="${1}"
local python_file="`pwd`/Adblock_sort.py"
if [ -f "$target_file" ] && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "domain" "$target_file"
else
	sort_domain_Combine "$target_file"
fi
}

#去除badfilter对应规则
function wipe_badfilter(){
local file="${1}"
test ! -f "${file}" && return 0
grep -E '(\$|\,)badfilter' "${file}" | while read fitter
do
	select_after=$(echo ${fitter} | busybox sed -E 's/\,badfilter$//g;s/\,badfilter\,/\,/g;s/\$badfilter//g')
	selector=$(escape_special_chars ${select_after})
	busybox sed -i -E "/^${selector}$/d" "${file}"
done
}

#避免大量字符影响观看
function Running_sort_domain_Combine(){
local IFS=$'\n'
local target_adblock_file="${1}"
test ! -f "${target_adblock_file}" && echo "※`date +'%F %T'` ${target_adblock_file} 规则文件不存在！！！" && return
sort_domain_Combine_python "${target_adblock_file}"
modtify_adblock_original_file "${target_adblock_file}"
wipe_same_selector_fiter "${target_adblock_file}"
modtify_adblock_original_file "${target_adblock_file}"
clear_domain_white_list "${target_adblock_file}"
modtify_adblock_original_file "${target_adblock_file}"
clear_domain_white_Rules "${target_adblock_file}"
}


#避免大量字符影响观看
function Running_sort_Css_Combine(){
local target_adblock_file="${1}"
test ! -f "${target_adblock_file}" && echo "※`date +'%F %T'` ${target_adblock_file} 规则文件不存在！！！" && return
#记录通用的Css
local css_common_record="$(cat ${target_adblock_file} 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' | grep -E '^#' )"
sort_Css_Combine_python "${target_adblock_file}"
#写入通用的Css
echo "${css_common_record}" >> "${target_adblock_file}"
busybox sed -i 's/换行符正则表达式n/\\/g' "${target_adblock_file}"
}

#规则分类
function sort_and_optimum_adblock(){
local file="${1}"
test ! -f "${file}" && return 
cat << key > "${file}"

!<<<<<通配符规则>>>>>`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -Ev '^\|\||^\|http|##|#\?#|#\%#|#\@#|##\[|##\.|[#][$][#]|[#][$][?][#]|[#][@][?][#]|^#' | sort | uniq | wc -l `
`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -Ev '^\|\||^\|http|##|#\?#|#\%#|#\@#|##\[|##\.|[#][$][#]|[#][$][?][#]|[#][@][?][#]|^#' | sort | uniq `
!<<<<<通配符规则 结束>>>>>

!<<<<<域名规则>>>>>`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^\|\||^\|http' | sort | uniq | wc -l `
`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^\|\||^\|http' | sort | uniq `
!<<<<<域名规则 结束>>>>>

!<<<<<网站单独规则>>>>>`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -Ev '^\@\@|^\|\||^\|http|^#|^\/|^:\/\/|^_|^\?|^\.|^-|^=|^:|^~|^,|^&|^\$|^\||^\*' | sort | uniq | wc -l`
`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -Ev '^\@\@|^\|\||^\|http|^#|^\/|^:\/\/|^_|^\?|^\.|^-|^=|^:|^~|^,|^&|^\$|^\||^\*' | sort | uniq `
!<<<<<网站单独规则 结束>>>>>

!<<<<<通用Css规则>>>>>`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^#|^~.*#' | sort | uniq | wc -l`
`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^#|^~.*#' | sort | uniq `
!<<<<<通用Css规则 结束>>>>>

!<<<<<放行白名单>>>>>`cat "${file}" | busybox sed '/^!/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^\@\@|#\@#' | sort | uniq | wc -l`
`cat "${file}" | busybox sed '/^!/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^\@\@|#\@#' | sort | uniq `
!<<<<<放行白名单 结束>>>>>

key
}

#剔除css规则冲突规则
function fixed_css_white_conflict_shell(){
local file="${1}"
local white_list=`cat ${file} | grep -E '^#\@#' | busybox sed -E 's/#\@#/##/g' `
for i in ${white_list}
do
	echo "剔除冲突规则 ${i}"
	rule=`escape_special_chars ${i}`
	busybox sed -i -E "/^${rule}$/d" "${file}"
done
}

#去除部分选择器
function wipe_same_selector_fiter_shell(){
local file="${1}"
local IFS=$'\n'
test ! -f "${file}" && return
local target_domain_list="$(grep -E '^\|\|' "${file}" | busybox sed -E 's/\$third-party$//g;s/\$popup$//g;s/\$third-party,important$//g;s/\$popup,third-party$//g;s/\$third-party,popup$//g;s/\$script$//g;s/\$image$//g;s/\$image,third-party$//g;s/\$third-party,image$//g;s/\$script,third-party$//g;s/\$third-party,script$//g;/domain=/d;/^!/d;/^[[:space:]]*$/d' | sort | uniq -d)"
local target_domain_list_count_all=$(echo "$target_domain_list" | wc -l)
local a=0
for i in $target_domain_list; do
	End_target=$((${target_domain_list_count_all} - $a))
	a=$(($a + 1))
	same_fiter_rule=$(escape_special_chars "${i}")
	busybox sed -i -E "/^${same_fiter_rule}\\$/d" "${file}"
	echo "※去除域名规则(${target_domain_list_count_all} → ${End_target}) ${i}"
done
}

#去除重复的域名规则
function clear_domain_white_list_shell(){
local file="${1}"
test ! -f "${file}" && return
cat "${file}" | busybox sed '/^\!/d;/\#/d;/\$/d' | grep -E '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:[0-9]{1,5})?(/[^ ]*)?' | sort -u | while read line
do
	transfer_content=`escape_special_chars ${line}`
	grep -E "^\|\|${transfer_content}\^" "${file}" && busybox sed -i -E "/^${transfer_content}$/d" "${file}"
done
}

#去除与白名单冲突的域名
function clear_domain_white_Rules_shell(){
local file="${1}"
test ! -f "${file}" && return
cat "${file}" | grep -E 'domain=~' | busybox sed '/#/d;s/\$.*//g' | while read line
do
	transfer_Rules=`escape_special_chars ${line}`
	busybox sed -i -E "/^${transfer_Rules}$/d" "${file}"
done
}

#修复低级错误
function fixed_Rules_error_shell(){
	local file="${1}"
	test ! -f "${file}" && return
	sed -i -E -e '/\$app=/d' \
	-e 's/=“/=\"/g' \
	-e 's/^[[:space:][:cntrl:]]//g' \
	-e 's/\*=“/\*=\"/g' \
	-e 's/\^=“/\^=\"/g' \
	-e 's/\$=“/\$=\"/g' \
	-e 's/”\]/\"\]/g' \
	-e 's/\]\]/\]/g' \
	-e 's/\[\[/\[/g' \
	-e 's/([^#])[[:cntrl:][:space:]./$]##/\1##/g' \
	-e 's/([^#])##[[:cntrl:][:space:]/$]/\1##/g' \
	-e 's/###[[:cntrl:][:space:].#/$]/###/g' \
	-e 's/##([[:digit:]]+)/##\\\1/g' \
	-e 's/##\.\[/##\[/g' \
	-e 's/^##[[:cntrl:][:space:]/$]/##/g' \
	-e 's/[[:space:]]\|/\|/g' \
	-e 's/\|[[:space:]]/\|/g' \
	-e 's/([^:])\:(after|before)/\1\:\:\2/g' "${file}"
#sed -i -E -e 's/(\[[:alpha:]|[\*\^\$])=([^"]*)(\])/\1="\2"\3/g' \
#	-e 's/(\[[:alpha:]|[\*\^\$]=\")([^"]*)\]/\1\2\"\]/g' \
#	-e 's/(\[[:alpha:]|[\*\^\$])=([^"]*)(\"\])/\1="\2\3/g' "${file}"
	gawk -i inplace '{ while (match($0, /^##[A-Z]+\[/)) { $0 = substr($0, 1, RSTART-1) tolower(substr($0, RSTART, RLENGTH)) substr($0, RSTART+RLENGTH) } print }' "${file}"
}


function fixed_css_white_conflict(){
local file="${1}"
test ! -f "${file}" && return
if command -v python3 >/dev/null 2>&1 ;then
	python3 "`pwd`/Adblock_sort_other.py" "css_conflict" "${file}"
else
	fixed_css_white_conflict_shell "${file}"
fi
}

function wipe_same_selector_fiter(){
local file="${1}"
test ! -f "${file}" && return
if command -v python3 >/dev/null 2>&1 ;then
	python3 "`pwd`/Adblock_sort_other.py" "wipe_selector" "${file}"
else
	wipe_same_selector_fiter_shell "${file}"
fi
}

function clear_domain_white_list(){
local file="${1}"
test ! -f "${file}" && return
if command -v python3 >/dev/null 2>&1 ;then
	python3 "`pwd`/Adblock_sort_other.py" "clear_white" "${file}"
else
	clear_domain_white_list_shell "${file}"
fi
}

function clear_domain_white_Rules(){
local file="${1}"
test ! -f "${file}" && return
if command -v python3 >/dev/null 2>&1 ;then
	python3 "`pwd`/Adblock_sort_other.py" "clear_white_rules" "${file}"
else
	clear_domain_white_Rules_shell "${file}"
fi
}

function fixed_Rules_error(){
local file="${1}"
test ! -f "${file}" && return
if command -v python3 >/dev/null 2>&1 ;then
    python3 "`pwd`/Adblock_sort_other.py" "fixed_error" "${file}"
else
	fixed_Rules_error_shell "${file}"
fi
}

#精简规则，剔除Via不支持的规则
function lite_Adblock_Rules(){
local file="${1}"
test ! -f "${file}" && return
local lite_content="$(cat ${file} | grep -Ev '#\@\?#|\$\@\$|#\%#|#\@\%#|#\@\$\?#|#\$\?#|#\$#|#\?#|##\+js\(|#\%#\/\/scriptlet|##\^|redirect=|removeparam=|\,replace=|redirect-rule=|\$removeparam|\$badfilter|\$empty|\$generichide|\$match-case|\$object|\$object-subrequest|\$~badfilter|\$~empty|\$~generichide|\$~removeparam|\$~match-case|\$~object|\$~object-subrequest|\,badfilter$|\,badfilter\,|\,empty$|\,empty\,|\,generichide$|\,generichide\,|\,match-case$|\,match-case\,|\,object$|\,object-subrequest$|\,object-subrequest\,|\,object\,|\,~badfilter$|\,~badfilter\,|\,~empty$|\,~empty\,|\,~generichide$|\,~generichide\,|\,~match-case$|\,~match-case\,|\,~object$|\,~object-subrequest$|\,~object-subrequest\,|\,~object\,|\$csp|\,csp=|\,denyallow=|permissions=|\:(matches-path|-abp-contains|-abp-properties|contains|has-text|matches-css|matches-css-before|matches-css-after|xpath|nth-ancestor|upward|remove|style|watch-attr)' | busybox sed -e '/^\!/d;/^[[:space:]]*$/d' \
 -e 's/\$3p/\$third-party/g' \
 -e 's/\$1p/\$~third-party/g' \
 -e 's/\$~3p/\$~third-party/g' \
 -e 's/\$~1p/\$third-party/g' \
 -e 's/\,1p$/\,~third-party/g' \
 -e 's/\,1p\,/\,~third-party\,/g' \
 -e 's/\,3p$/\,third-party/g' \
 -e 's/\,3p\,/\,third-party\,/g' \
 -e 's/\,~1p$/\,third-party/g' \
 -e 's/\,~1p\,/\,third-party\,/g' \
 -e 's/\,~3p$/\,~third-party/g' \
 -e 's/\,~3p\,/\,~third-party\,/g' \
 -e 's/\,strict3p/\,third-party/g' \
 -e 's/\$strict3p/\$third-party/g' \
 -e 's/\$xhr/\$xmlhttprequest/g' \
 -e 's/\$~xhr/\$~xmlhttprequest/g' \
 -e 's/\,xhr\,/\,xmlhttprequest\,/g' \
 -e 's/\,xhr$/\,xmlhttprequest/g' \
 -e 's/\,~xhr\,/\,~xmlhttprequest\,/g' \
 -e 's/\,~xhr$/\,~xmlhttprequest/g' \
 -e 's/\$css/\$stylesheet/g' \
 -e 's/\$~css/\$~stylesheet/g' \
 -e 's/\,css$/\,stylesheet/g' \
 -e 's/\,css\,/\,stylesheet\,/g' \
 -e 's/\,~css$/\,~stylesheet/g' \
 -e 's/\,~css\,/\,~stylesheet\,/g' \
 -e 's/\$important$//g' \
 -e 's/\$important,/\$/g' \
 -e 's/\,important\,/\,/g' \
 -e 's/\,important$//g' \
 -e 's/\$~important$//g' \
 -e 's/\$~important,/\$/g' \
 -e 's/\,~important\,/\,/g' \
 -e 's/\,~important$//g' \
 -e 's/\$popup$//g' \
 -e 's/\$popup,/\$/g' \
 -e 's/\,popup\,//g' \
 -e 's/\,popup$//g' \
 -e 's/\$~popup$//g' \
 -e 's/\$~popup,/\$/g' \
 -e 's/\,~popup\,//g' \
 -e 's/\,~popup$//g' \
 -e 's/\$document$//g' \
 -e 's/\$document,/\$/g' \
 -e 's/\,document\,//g' \
 -e 's/\,document$//g' \
 -e 's/\$~document$//g' \
 -e 's/\$~document,/\$/g' \
 -e 's/\,~document\,//g' \
 -e 's/\,~document$//g' \
 -e 's/\$all$//g' \
 -e 's/\$all,/\$/g' \
 -e 's/\,all\,//g' \
 -e 's/\,all$//g' \
 -e 's/\$~all$//g' \
 -e 's/\$~all,/\$/g' \
 -e 's/\,~all\,//g' \
 -e 's/\,~all$//g' \
 -e 's/\$doc$//g' \
 -e 's/\$doc,/\$/g' \
 -e 's/\,doc\,//g' \
 -e 's/\,doc$//g' \
 -e 's/\$~doc$//g' \
 -e 's/\$~doc,/\$/g' \
 -e 's/\,~doc\,//g' \
 -e 's/\,~doc$//g' | sort | uniq)"
echo "${lite_content}" > "${file}"
}

#adblock限定器缩写转换，将特定缩写转换为完整形式
function convert_abbreviations() {
local file="${1}"
test ! -f "${file}" && return 0
local converted_content="$(cat "${file}" | busybox sed \
 -e 's/\$3p/\$third-party/g' \
 -e 's/\$1p/\$~third-party/g' \
 -e 's/\$~3p/\$~third-party/g' \
 -e 's/\$~1p/\$third-party/g' \
 -e 's/\,1p$/\,~third-party/g' \
 -e 's/\,1p\,/\,~third-party\,/g' \
 -e 's/\,3p$/\,third-party/g' \
 -e 's/\,3p\,/\,third-party\,/g' \
 -e 's/\,~1p$/\,third-party/g' \
 -e 's/\,~1p\,/\,third-party\,/g' \
 -e 's/\,~3p$/\,~third-party/g' \
 -e 's/\,~3p\,/\,~third-party\,/g' \
 -e 's/\$xhr/\$xmlhttprequest/g' \
 -e 's/\$~xhr/\$~xmlhttprequest/g' \
 -e 's/\,xhr\,/\,xmlhttprequest\,/g' \
 -e 's/\,xhr$/\,xmlhttprequest/g' \
 -e 's/\,~xhr\,/\,~xmlhttprequest\,/g' \
 -e 's/\,~xhr$/\,~xmlhttprequest/g' \
 -e 's/\$css/\$stylesheet/g' \
 -e 's/\$~css/\$~stylesheet/g' \
 -e 's/\,css$/\,stylesheet/g' \
 -e 's/\,css\,/\,stylesheet\,/g' \
 -e 's/\,~css$/\,~stylesheet/g' \
 -e 's/\,~css\,/\,~stylesheet\,/g' \
 -e 's/\$doc/\$document/g' \
 -e 's/\$~doc/\$~document/g' \
 -e 's/\,doc\,/\,document\,/g' \
 -e 's/\,doc$/\,document/g' \
 -e 's/\,~doc\,/\,~document\,/g' \
 -e 's/\,~doc$/\,~document/g' )"
echo "${converted_content}" > "${file}"
}

#在Via支持正则表达式前先移除正则表达式，减少报错和资源占用。
function Remove_regex_Rules_for_via(){
local file="${1}"
test ! -f "${file}" && return
busybox sed -i -E '/\\\//d;/\\\./d;/\\\?/d' "${file}"
}

#精简规则 去除Ublock不支持的规则
function lite_Uadblock_Rules(){
local file="${1}"
test ! -f "${file}" && return
local lite_content="$(cat ${file} | grep -Ev '\$\$|\$@\$|#\%#|#\@\%#|#\@\$\?#|#\$\?#|#\%#\/\/scriptlet|\$dnsrewrite=|\,replace=|:-abp-properties|:matches-attr|:matches-property|:nth-ancestor' | sort | uniq)"
echo "${lite_content}" > "${file}"
}

#去除转换popup选定器，直接改用||域名^的形式。
function wipe_fiter_popup_domain(){
local file="${1}"
test ! -f "${file}" && return 
busybox sed -i -E 's/\$popup$//g;s/\$popup,third-party$/\$third-party/g;s/\$third-party,popup$/\$third-party/g;s/\$popup,~third-party$/\$~third-party/g;s/\$~third-party,popup$/\$~third-party/g;s/\$document$//g;s/\$popup,document$//g;s/\$document,popup$//g;s/\$all$//g;s/\$popup,all$//g;s/\$all,popup$//g' "${file}"
#busybox sed -i -E '/^\|\|[0-9]+\.[0-9]+\./d' "${file}"
}

#更新README信息
function update_README_info(){
local file="`pwd`/README.md"
test -f "${file}" && rm -rf "${file}"
cat << key > "${file}"
# 混合规则
### 自动更新(`date +'%F %T'`)


| 名称 | GIthub订阅链接 | Jsdelivrcdn缓存链接 | ~~GitCode订阅链接(死了)~~ | Gitlink订阅链接(竟然又活了) |
| :-- | :-- | :-- | :-- | :-- |
| 混合规则(自动更新) | [订阅](https://raw.githubusercontent.com/lingeringsound/adblock_auto/main/Rules/adblock_auto.txt) | [订阅](https://cdn.jsdelivr.net/gh/lingeringsound/adblock_auto@main/Rules/adblock_auto.txt) | ~~[订阅](https://gitcode.net/weixin_45617236/adblock_auto/-/raw/main/Rules/adblock_auto.txt)~~ | [订阅](https://cdn09022024.gitlink.org.cn/api/v1/repos/keytoolazy/adblock_auto/raw/Rules/adblock_auto.txt?ref=main&access_token=9aa2be1250ca725d0ef1b1f638fb3de408a11335) |
| 混合规则精简版(自动更新) | [订阅](https://raw.githubusercontent.com/lingeringsound/adblock_auto/main/Rules/adblock_auto_lite.txt) | [订阅](https://cdn.jsdelivr.net/gh/lingeringsound/adblock_auto@main/Rules/adblock_auto_lite.txt) | ~~[订阅](https://gitcode.net/weixin_45617236/adblock_auto/-/raw/main/Rules/adblock_auto_lite.txt)~~ | [订阅](https://cdn09022024.gitlink.org.cn/api/v1/repos/keytoolazy/adblock_auto/raw/Rules/adblock_auto_lite.txt?ref=main&access_token=9aa2be1250ca725d0ef1b1f638fb3de408a11335) |


### 拦截器说明
> #### [混合规则(自动更新)](https://lingeringsound.github.io/adblock_auto/Rules/adblock_auto.txt) 适用于 \`Adguard\` / \`Ublock Origin\` / \`Adblock Plus\`(用Adblock Plus源码编译的软件也支持，例如[嗅觉浏览器](https://www.coolapk.com/apk/com.hiker.youtoo) ) 支持复杂语法的过滤器，或者能兼容大规则的浏览器例如 [X浏览器](https://www.coolapk.com/apk/com.mmbox.xbrowser)

> #### [混合规则精简版(自动更新)](https://lingeringsound.github.io/adblock_auto/Rules/adblock_auto_lite.txt) 适用于轻量的浏览器，例如  [VIA](https://www.coolapk.com/apk/mark.via)  / [Rian](https://www.coolapk.com/apk/com.rainsee.create) / [B仔浏览器](https://www.coolapk.com/apk/com.huicunjun.bbrowser)


### 上游规则
#### 感谢各位大佬❤ (ɔˆз(ˆ⌣ˆc)
<details>
<summary>点击查看上游规则</summary>
<ul>
<li> <a href="https://easylist-downloads.adblockplus.org/easylist.txt" target="_blank" > Easylist </a> </li>
<li> <a href="https://easylist-downloads.adblockplus.org/easylistchina.txt" target="_blank" > EasylistChina </a> </li>
<li> <a href="https://raw.githubusercontent.com/easylist/easylist/refs/heads/master/easylist/easylist_adservers_popup.txt" target="_blank" > Easylist adservers popup </a> </li>
<li> <a href="https://easylist-downloads.adblockplus.org/antiadblockfilters.txt" target="_blank" > Antiadblockfilters </a> </li>
<li> <a href="https://filters.adtidy.org/android/filters/15_optimized.txt" target="_blank" > Adguard DNS optimized </a> </li>
<li> <a href="https://filters.adtidy.org/extension/ublock/filters/11.txt" target="_blank" > Adguard mobile </a> </li>
<li> <a href="https://filters.adtidy.org/extension/ublock/filters/224.txt" target="_blank" > Adguard Chinese </a> </li>
<li> <a href="https://filters.adtidy.org/extension/ublock/filters/2_optimized.txt" target="_blank" > AdGuard Base filter </a> </li>
</ul>
</details>

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=lingeringsound/adblock_auto&type=Date)](https://star-history.com/#lingeringsound/adblock_auto&Date)

key
}