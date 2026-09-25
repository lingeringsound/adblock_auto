#!/bin/sh
export PATH="`pwd`:${PATH}"

#使用magisk的busybox sed
#主要我本地规则用的就是magisk的busybox，GNU的sed -iE 在白名单方面有问题。
command -v busybox >/dev/null 2>&1 && sed() { busybox sed "${@}"; }

#定义 python 以及 Perl 插件的目录
Adblock_Tools_Plugin_Folder="$(pwd)/plugin"

#安全写入文件，避免转换\\ 和 Unicode字符
function write_notran_file() {
local content="${1}"
local file="${2}"
local flag="${3}"
[ -z "${file}" ] && return
[ -z "${flag}" ] && flag=">"
if [ "$(command -v printf)" = "printf" ]; then
	if [ "${flag}" = ">>" ]; then
		printf '%s\n' "${content}" >> "$file"
	else
		printf '%s\n' "${content}" > "$file"
	fi
elif [ "$(command -v print)" = "print" ]; then
	if [ "${flag}" = ">>" ]; then
		print -r -- "${content}" >> "$file"
	else
		print -r -- "${content}" > "$file"
	fi
else
	if [ "${flag}" = ">>" ]; then
cat >> "$file" << EOF
${content}
EOF
	else
cat > "$file" << EOF
${content}
EOF
	fi
fi
}

#移除Adguard_Chinese的秋风规则
function remove_AWAvenue_Ads_Rule_Filter(){
local file="${1}"
test ! -f "${file}" && return
sed -i "/AWAvenue Ads Rule/,/^$/d" "${file}"
}

#转换文件为UTF-8编码
function convert_enc_to_UTF() {
local file="$1"
local output_file="${2:-$file}"
local python_file="${Adblock_Tools_Plugin_Folder}/convert_enc.py"
[ -f "$file" ] || return
if command -v python3 >/dev/null 2>&1 && [ -f "${python_file}" ]; then
	[ "${file}" = "${output_file}" ] && python3 "${python_file}" "${file}" || python3 "${python_file}" "${file}" "${output_file}"
else
	dos2unix "$file" >/dev/null 2>&1
fi
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
sed -i 's/\\n/换行符正则表达式nn/g' "${target_dir}/${name}"
test "${name}" = "Adguard_Chinese.txt" && remove_AWAvenue_Ads_Rule_Filter "${target_dir}/${name}"
convert_enc_to_UTF "${target_dir}/${name}"
done
}

#写入基本信息
function write_head(){
local file="${1}"
local Description="${3}"
test "${Description}" = "" && Description="${2}"
local count=`sed '/^!/d;/^[[:space:]]*$/d' "${file}" | wc -l ` 
local original_file=`cat "${file}"`
cat > "${file}" << key
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

${original_file}
key
sed -i 's/换行符正则表达式n/\\/g' "${file}"
local checksum_file="${Adblock_Tools_Plugin_Folder}/addchecksum.py"
if command -v python >/dev/null 2>&1 && [ -f "${checksum_file}" ]; then 
	python "${checksum_file}" "${file}"
elif command -v perl >/dev/null 2>&1 && [ -f "${checksum_file%%.*}.pl" ]; then
	perl "${checksum_file%%.*}.pl" "${file}"
fi
}

#净化规则
function modtify_adblock_original_file() {
local file="${1}"
local exclude_re='^#(@(\?|%|\$\?)#|(%|\$\?)#)|^\$@\$|^<<|<<1023<<'
local new
[ -f "$file" ] || return
sed -i 's/\\n/换行符正则表达式nn/g' "${file}"
if test "${2}" = "" ;then
	new=`grep -Ev "${exclude_re}" "${file}" | sed 's|^[[:space:]]@@|@@|g;/^!/d;/^\[.*\]$/d;/^[[:space:]]*$/d' | sort -u `
	write_notran_file "$new" "${file}"
else
	new=`grep -Ev "${exclude_re}|${2}" "${file}" | sed 's|^[[:space:]]@@|@@|g;/^!/d;/^\[.*\]$/d;/^[[:space:]]*$/d' | sort -u `
	write_notran_file "$new" "${file}"
fi
}

function make_white_rules(){
local file="${1}"
local IFS=$'\n'
local white_list_file="${2}"
for o in `sed '/^!/d;/^[[:space:]]*$/d' "${white_list_file}" 2>/dev/null `
do
	sed -i -E "/${o}/d" "${file}"
done
}

function fix_Rules(){
local file="${1}"
local target_content="${2}"
local fix_content="${3}"
test ! -f "${file}" -o "${fix_content}" = "" && return 
sed -i "s|${target_content}|${fix_content}|g" "${file}"
}

function Combine_adblock_original_file(){
local file="${1}"
local target_folder="${2}"
test "${target_folder}" = "" && echo "※`date +'%F %T'` 请指定合并目录……" && exit
: > "${file}"
for i in "${target_folder}"/*.txt "${target_folder}"/*.prop
do
	[ -f "${i}" ] || continue
	dos2unix "${i}" >/dev/null 2>&1
	cat "${i}" >> "${file}"
done
}

#筛选整理规则
function wipe_white_list() {
	local file="${2}"
	local output_folder="${1}"
	if test -f "${file}" ;then
	local IFS=$'\n'
	local new=$(grep -Ev "${3}" "${file}" | sort -u | sed '/^!/d;/^[[:space:]]*$/d' )
		mkdir -p "${output_folder}"
		write_notran_file "$new" "${output_folder}/${file##*/}"
	fi
}

function sort_web_rules() {
	local file="${2}"
	local output_folder="${1}"
	local output_file="${output_folder}/${file##*/}"
	if test -f "${file}" ;then
		local IFS=$'\n'
		local new=$(grep -Ev '^@@|^[[:space:]]@@\|\||^<<|<<1023<<|^\|\||^##|^[?_./=&:~,$|*-]|/ad/|^#\$#|#@#|^#%#|^!|^[[:space:]]*$' "${file}" | sort -u )
			mkdir -p "${output_folder}"
		write_notran_file "$new" "${output_file}" ">>"
	fi
}

function sort_adblock_Rules() {
	local file="${2}"
	local output_folder="${1}"
	if test -f "${file}" ;then
		local IFS=$'\n'
		local new=$(grep -E "${3}" "${file}" | sort -u | sed '/^!/d;/^[[:space:]]*$/d' )
			mkdir -p "${output_folder}"
		write_notran_file "$new" "${output_folder}/${file##*/}"
	fi
}

function add_rules_file() {
	local file="${2}"
	local output_folder="${1}"
	local IFS=$'\n'
	local new=$(grep -E "${3}" "${file}" | sort -u | sed '/^!/d;/^[[:space:]]*$/d' )
	if test -f "${output_folder}/${file##*/}" ;then
		mkdir -p "${output_folder}"
				write_notran_file "$new" "${output_folder}/${file##*/}" ">>"
			local sort_file=`cat "${output_folder}/${file##*/}" | sort -u | sed '/^!/d;/^[[:space:]]*$/d' `
		write_notran_file "${sort_file}" "${output_folder}/${file##*/}"
	fi
}

# 转换成原生 has 规则
function add_has_fiter() {
local file="${1}"
local target_folder="${2}"
local target_website="${3}"
test ! -f "${file}" -o ! -d "${target_folder}" && return
local exclude=':-abp-contains|:-abp-properties|:contains|:has-text'
exclude="${exclude}|:matches-attr|:matches-css|:matches-css-after|:matches-css-before"
exclude="${exclude}|:matches-path|:matches-property|:min-text-length|:nth-ancestor"
exclude="${exclude}|:remove|:style|:upward|:watch-attr|:xpath"
exclude="${exclude}|[[:space:]]\{[[:space:]]remove:[[:space:]]true;[[:space:]]\}"
exclude="${exclude}|^#|^!|^\[|\*#"
local site_filter='^'
test -n "${target_website}" && site_filter="${target_website}"
local has_fiter="$(grep -E ':-abp-has|:has' "${file}" \
 | grep -E "${site_filter}" \
 | grep -Ev "${exclude}" \
 | sed -E 's/#(#|[@?]#)?/##/g;s/:-abp-has/:has/g' \
 | sort -u)"
write_notran_file "${has_fiter}" "${target_folder}/${file##*/}_has.txt"
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
	local output=$(echo ${input} | sed 's/[\^\|\*\?\$\=\@\/\.\"\+\;\(\)\{\}]/\\&/g;s|\[|\\&|g;s|\]|\\&|g' )
	echo ${output}
}

#去除指定重复的Css
function sort_Css_Combine(){
local IFS=$'\n'
local target_file="${1}"
local target_file_tmp="`pwd`/${target_file##*/}.tmp"
local target_output_file="`pwd`/${target_file##*/}.temple"
local count_Rules_all=`grep '#' "${target_file}" | sed '/^#/d;/^!/d;/^\|\|/d;/^\//d' | sed -E 's/.*\.[A-Za-z]{2,8}#{1,1}//g' | sort | uniq -d | wc -l`
local a=0
sed -i 's/\\n/换行符正则表达式nn/g' "${target_file}"
local new_file=$(sort -u "${target_file}" | sed '/^!/d;/^[[:space:]]*$/d;/^\[.*\]$/d' )
write_notran_file "${new_file}" "${target_file}"
for target_content in `grep '#' "${target_file}" | sed '/^#/d;/^!/d;/^\|\|/d;/^\//d' | sed -E 's/.*\.[A-Za-z]{2,8}#{1,1}//g' | sort | uniq -d `
do
a=$(($a + 1))
target_content="#${target_content}"
transfer_content=$(escape_special_chars ${target_content})
grep -E "${transfer_content}$" "${target_file}" > "${target_file_tmp}" && echo "※处理重复Css规则( $count_Rules_all → $(($count_Rules_all - ${a})) ): ${transfer_content}$"
if test "$(sed 's|#.*||g' "${target_file_tmp}" 2>/dev/null | grep -E ',')" != "" ;then
	sed -i 's|#.*||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | tr ',' '\n' | sed '/^[[:space:]]*$/d' | sort -u )
	write_notran_file "${before_tmp}" "${target_file_tmp}"
	sed -i ":a;N;\$!ba;s#\n#,#g" "${target_file_tmp}"
	if test "$(sed '/^!/d;/^[[:space:]]*$/d' "${target_file_tmp}" 2>/dev/null )" != "" ;then 
		grep -Ev "${transfer_content}$" "${target_file}" >> "${target_output_file}" 
cat >> "${target_output_file}" << key
`cat "${target_file_tmp}"`${target_content}
key
		mv -f "${target_output_file}" "${target_file}"
	fi
else
	sed -i 's|#.*||g' "${target_file_tmp}"
	local before_tmp=$(sed '/^[[:space:]]*$/d' "${target_file_tmp}" | sort -u)
	write_notran_file "${before_tmp}" "${target_file_tmp}"
	if test "$(sed '/^!/d;/^[[:space:]]*$/d' "${target_file_tmp}" 2>/dev/null | wc -l)" -gt "1" ;then
		sed -i ":a;N;\$!ba;s#\n#,#g" "${target_file_tmp}"
	fi
	if test "$(sed '/^!/d;/^[[:space:]]*$/d' "${target_file_tmp}" 2>/dev/null )" != "" ;then 
		grep -Ev "${transfer_content}$" "${target_file}" >> "${target_output_file}" 
cat >> "${target_output_file}" << key
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
local count_Rules_all=`sed 's|domain=.*||g' "${target_file}" | sort | uniq -d | sed '/^[[:space:]]*$/d' | wc -l `
local a=0
sed -i 's/\\n/换行符正则表达式nn/g' "${target_file}"
local new_file=$(sort -u "${target_file}" | sed '/^!/d;/^[[:space:]]*$/d;/^\[.*\]$/d' )
write_notran_file "${new_file}" "${target_file}"
for target_content in `grep 'domain=' "${target_file}" | sed 's|domain=.*||g' | sort | uniq -d | sed '/^[[:space:]]*$/d' `
do
a=$(($a + 1))
target_content="${target_content}domain="
transfer_content=$(escape_special_chars ${target_content} )
grep -E "^${transfer_content}" "${target_file}" > "${target_file_tmp}" && echo "※处理重复作用域名规则( $count_Rules_all → $(($count_Rules_all - ${a} )) ): ^${transfer_content}"
if test "$(sed 's|.*domain=||g' "${target_file_tmp}" 2>/dev/null | grep -E ',' )" != "" ;then
	echo "※规则 ${target_content} 包含其他限定器！"
	local fixed_tmp=$(sed 's/[[:space:]]$//g' "${target_file_tmp}" | grep -Ev ',(important|third-party|script|media|subdocument|document|xmlhttprequest|other|stealth|image|stylesheet|content|match-case|font|sitekey|popup|xhr|object|generichide|genericblock|elemhide|all|badfilter|websocket|~important|~third-party|~script|~media|~subdocument|~document|~xmlhttprequest|~other|~stealth|~image|~stylesheet|~content|~match-case|~font|~sitekey|~popup|~xhr|~object|~generichide|~genericblock|~elemhide|~all|~badfilter|~websocket)$' | sed '/^[[:space:]]*$/d' | sort -u)
	write_notran_file "${fixed_tmp}" "${target_file_tmp}"
	echo "※尝试修复中……"
	local Rules_juggle=`sort -u "${target_file_tmp}" | sed '/^[[:space:]]*$/d' | wc -l`
	test "${Rules_juggle}" -le "1" && echo "※无法合并，已跳过！" && continue
fi
if test "$(sed 's|.*domain=||g' "${target_file_tmp}" 2>/dev/null | grep -E '\|')" != "" ;then
	sed -i 's|.*domain=||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | tr '|' '\n' | sed '/^[[:space:]]*$/d' | sort  | uniq)
	write_notran_file "${before_tmp}" "${target_file_tmp}"
	sed -i ":a;N;\$!ba;s#\n#\|#g" "${target_file_tmp}"
	if test "$(sed '/^!/d;/^[[:space:]]*$/d' "${target_file_tmp}" 2>/dev/null )" != "" ;then 
		grep -Ev "^${transfer_content}" "${target_file}" >> "${target_output_file}" 
cat >> "${target_output_file}" << key
${target_content}`cat "${target_file_tmp}"`
key
		mv -f "${target_output_file}" "${target_file}"
	fi
else
	sed -i 's|.*domain=||g' "${target_file_tmp}"
	local before_tmp=$(sed '/^[[:space:]]*$/d' "${target_file_tmp}" | sort -u )
	write_notran_file "${before_tmp}" "${target_file_tmp}"
	if test "$(sed '/^!/d;/^[[:space:]]*$/d' "${target_file_tmp}" 2>/dev/null | wc -l)" -gt "1" ;then
		sed -i ":a;N;\$!ba;s#\n#\|#g" "${target_file_tmp}"
	fi
	if test "$(sed '/^!/d;/^[[:space:]]*$/d' "${target_file_tmp}" 2>/dev/null )" != "" ;then 
		grep -Ev "^${transfer_content}" "${target_file}" >> "${target_output_file}"
cat >> "${target_output_file}" << key
${target_content}`cat "${target_file_tmp}"`
key
		mv -f "${target_output_file}" "${target_file}"
	fi
fi
done
rm -rf "${target_file_tmp}" 2>/dev/null
sed -i 's/换行符正则表达式n/\\/g' "${target_file}"
}


#去重函数python版
function sort_Css_Combine_python() {
local target_file="${1}"
local python_file="${Adblock_Tools_Plugin_Folder}/Adblock_sort.py"
if [ -f "$target_file" ] && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "css" "$target_file"
else
	sort_Css_Combine "$target_file"
fi
}

function sort_domain_Combine_python() {
local target_file="${1}"
local python_file="${Adblock_Tools_Plugin_Folder}/Adblock_sort.py"
if [ -f "$target_file" ] && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "domain" "$target_file"
	python3 "${python_file}" "denyallow" "$target_file"
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
	select_after=$(echo ${fitter} | sed -E 's/\,badfilter$//g;s/\,badfilter\,/\,/g;s/\$badfilter//g')
	selector=$(escape_special_chars ${select_after})
	sed -i -E "/^${selector}$/d" "${file}"
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
#local css_common_record="$(cat ${target_adblock_file} 2>/dev/null | sed '/^!/d;/^[[:space:]]*$/d' | grep -E '^#' )"
sort_Css_Combine_python "${target_adblock_file}"
#写入通用的Css
#write_notran_file "${css_common_record}" "${target_adblock_file}" ">>"
fixed_css_selector_not_clean "${target_adblock_file}"
sed -i 's/换行符正则表达式n/\\/g' "${target_adblock_file}"
}

#规则分类
function sort_and_optimum_adblock_shell(){
local file="${1}"
test ! -f "${file}" && return
local common_Rules="`sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' "${file}" | grep -Ev '^\|\||^\|http|##|#\?#|#\%#|#\@#|##\[|##\.|[#][$][#]|[#][$][?][#]|[#][@][?][#]|^#' | sort -u `"
local domain_Rules="`sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' "${file}" | grep -E '^\|\||^\|http' | sort -u `"
local single_website_Rules="`sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' "${file}" | grep -Ev '^\@\@|^\|\||^\|http|^#|^\/|^:\/\/|^_|^\?|^\.|^-|^=|^:|^~|^,|^&|^\$|^\||^\*' | sort -u `"
local comm_Css_Rules="`sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' "${file}" | grep -E '^#|^~.*#' | sort -u `"
local white_List_Rules="`sed '/^!/d;/^\[/d;/^[[:space:]]*$/d' "${file}" | grep -E '^\@\@|#\@#' | sort -u `"
cat > "${file}" << key

!<<<<<通配符规则>>>>>`echo "${common_Rules}" | wc -l `
${common_Rules}
!<<<<<通配符规则 结束>>>>>

!<<<<<域名规则>>>>>`echo "$domain_Rules" | wc -l `
${domain_Rules}
!<<<<<域名规则 结束>>>>>

!<<<<<网站单独规则>>>>>`echo "$single_website_Rules" | wc -l`
${single_website_Rules}
!<<<<<网站单独规则 结束>>>>>

!<<<<<通用Css规则>>>>>`echo "$comm_Css_Rules" | wc -l`
${comm_Css_Rules}
!<<<<<通用Css规则 结束>>>>>

!<<<<<放行白名单>>>>>`echo "$white_List_Rules" | wc -l`
${white_List_Rules}
!<<<<<放行白名单 结束>>>>>

key
}

function sort_and_optimum_adblock() {
local file="${1}"
test ! -f "${file}" && return 
local python_file="${Adblock_Tools_Plugin_Folder}/sort_and_optimum_adblock.py"
if command -v python3 >/dev/null 2>&1 && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "$file"
else
	sort_and_optimum_adblock_shell "$file"
fi
}

#剔除css规则冲突规则
function fixed_css_white_conflict_shell(){
local file="${1}"
local white_list=`grep -E '^#\@#' "${file}" | sed -E 's/#\@#/##/g' `
for i in ${white_list}
do
	echo "剔除冲突规则 ${i}"
	rule=`escape_special_chars ${i}`
	sed -i -E "/^${rule}$/d" "${file}"
done
}

#去除部分选择器
function wipe_same_selector_fiter_shell(){
local file="${1}"
local IFS=$'\n'
test ! -f "${file}" && return
local target_domain_list="$(grep -E '^\|\|' "${file}" | sed -E 's/\$third-party$//g;s/\$popup$//g;s/\$third-party,important$//g;s/\$popup,third-party$//g;s/\$third-party,popup$//g;s/\$script$//g;s/\$image$//g;s/\$image,third-party$//g;s/\$third-party,image$//g;s/\$script,third-party$//g;s/\$third-party,script$//g;/domain=/d;/^!/d;/^[[:space:]]*$/d' | sort | uniq -d)"
local target_domain_list_count_all=$(echo "$target_domain_list" | wc -l)
local a=0
for i in $target_domain_list; do
	End_target=$((${target_domain_list_count_all} - $a))
	a=$(($a + 1))
	same_fiter_rule=$(escape_special_chars "${i}")
	sed -i -E "/^${same_fiter_rule}\\$/d" "${file}"
	echo "※去除域名规则(${target_domain_list_count_all} → ${End_target}) ${i}"
done
}

#去除重复的域名规则
function clear_domain_white_list_shell(){
local file="${1}"
test ! -f "${file}" && return
sed '/^\!/d;/\#/d;/\$/d' "${file}" | grep -E '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:[0-9]{1,5})?(/[^ ]*)?' | sort -u | while read line
do
	transfer_content=`escape_special_chars ${line}`
	grep -E "^\|\|${transfer_content}\^" "${file}" && sed -i -E "/^${transfer_content}$/d" "${file}"
done
}

#去除与白名单冲突的域名
function clear_domain_white_Rules_shell(){
local file="${1}"
test ! -f "${file}" && return
grep -E 'domain=~' "${file}" | sed '/#/d;s/\$.*//g' | while read line
do
	transfer_Rules=`escape_special_chars ${line}`
	sed -i -E "/^${transfer_Rules}$/d" "${file}"
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
local python_file="${Adblock_Tools_Plugin_Folder}/Adblock_sort_other.py"
if command -v python3 >/dev/null 2>&1 && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "css_conflict" "${file}"
else
	fixed_css_white_conflict_shell "${file}"
fi
}

function fixed_css_selector_not_clean(){
local file="${1}"
test ! -f "${file}" && return
local python_file="${Adblock_Tools_Plugin_Folder}/Adblock_sort_other.py"
if command -v python3 >/dev/null 2>&1 && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "css_selector_not_clean" "${file}"
fi
}

function wipe_same_selector_fiter(){
local file="${1}"
test ! -f "${file}" && return
local python_file="${Adblock_Tools_Plugin_Folder}/Adblock_sort_other.py"
if command -v python3 >/dev/null 2>&1 && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "wipe_selector" "${file}"
else
	wipe_same_selector_fiter_shell "${file}"
fi
}

function clear_domain_white_list(){
local file="${1}"
test ! -f "${file}" && return
local python_file="${Adblock_Tools_Plugin_Folder}/Adblock_sort_other.py"
if command -v python3 >/dev/null 2>&1 && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "clear_white" "${file}"
else
	clear_domain_white_list_shell "${file}"
fi
}

function clear_domain_white_Rules(){
local file="${1}"
test ! -f "${file}" && return
local python_file="${Adblock_Tools_Plugin_Folder}/Adblock_sort_other.py"
if command -v python3 >/dev/null 2>&1 && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "clear_white_rules" "${file}"
else
	clear_domain_white_Rules_shell "${file}"
fi
}

function fixed_Rules_error(){
local file="${1}"
test ! -f "${file}" && return
local python_file="${Adblock_Tools_Plugin_Folder}/Adblock_sort_other.py"
if command -v python3 >/dev/null 2>&1 && [ -f "${python_file}" ] ;then
    python3 "${python_file}" "fixed_error" "${file}"
else
	fixed_Rules_error_shell "${file}"
fi
}

#精简规则，剔除Via不支持的规则
#2026.09.19 grep 加入了正则移除 -e '^/(\^|\\|\[|\(\?)' 
#该规则和 Remove_regex_Rules_for_via 相似 是粗略过滤
#2026.09.20 sed 改为 sed -E 使用正则来缩短行数和方便维护，不要除去-E选项，不然无法过滤
function lite_Adblock_Rules(){
local file="${1}"
test ! -f "${file}" && return
local lite_content="$(grep -Ev \
 -e '#(@?[%$?]+)#' \
 -e '#@?#\+js\(' \
 -e '#@?#\^' \
 -e '\$@\$' \
 -e '(\$|,)~?(badfilter|empty|generichide|match-case|object|object-subrequest|removeparam)(,|$)' \
 -e '(\$|,)~?(csp|redirect-rule)(,|=|$)' \
 -e '(\$|,)~?(cname|genericblock|ghide|elemhide|ping|popunder)(,|$)' \
 -e '(\$|,)(redirect|removeparam|header|replace|urlskip|uritransform|ipaddress|method|csp|denyallow|permissions|to)=' \
 -e ':(matches-path|-abp-contains|-abp-properties|contains|has-text|matches-css|matches-css-before|matches-css-after|xpath|nth-ancestor|upward|remove|style|watch-attr|matches-attr|matches-property|min-text-length)' \
 -e ':others\(|:shadow\(' \
 -e '^/(\^|\\|\[|\(\?)' \
 -e '^\*$' \
 "${file}" | sed -E \
  -e '/^\!/d' \
  -e '/^[[:space:]]*$/d' \
  -e 's/(\$|,)from=/\1domain=/g' \
  -e 's/(\$|,)strict3p(,|$)/\1third-party\2/g' \
  -e 's/(\$|,)(~?)3p(,|$)/\1\2third-party\3/g' \
  -e 's/(\$|,)~1p(,|$)/\1third-party\2/g' \
  -e 's/(\$|,)1p(,|$)/\1~third-party\2/g' \
  -e 's/(\$|,)(~?)xhr(,|$)/\1\2xmlhttprequest\3/g' \
  -e 's/(\$|,)(~?)css(,|$)/\1\2stylesheet\3/g' \
  -e 's/(\$|,)(~?)i?frame(,|$)/\1\2subdocument\3/g' \
  -e 's/\$~?(important|popup|document|all|doc)(,|$)/$\2/g' \
  -e 's/,~?(important|popup|document|all|doc)(,|$)/\2/g' \
  -e 's/\$,/$/g' \
  -e 's/,,/,/g' \
  -e 's/\$$//' | sort -u )"
write_notran_file "${lite_content}" "${file}"
}

#adblock限定器缩写转换，将特定缩写转换为完整形式
function convert_abbreviations() {
local file="${1}"
test ! -f "${file}" && return 0
local converted_content="$(sed -E \
  -e 's/(\$|,)(~?)3p(,|$)/\1\2third-party\3/g' \
  -e 's/(\$|,)(~?)xhr(,|$)/\1\2xmlhttprequest\3/g' \
  -e 's/(\$|,)(~?)css(,|$)/\1\2stylesheet\3/g' \
  -e 's/(\$|,)(~?)doc(,|$)/\1\2document\3/g' \
  -e 's/(\$|,)(~?)i?frame(,|$)/\1\2subdocument\3/g' \
  -e 's/(\$|,)~1p(,|$)/\1third-party\2/g' \
  -e 's/(\$|,)1p(,|$)/\1~third-party\2/g' "${file}" )"
write_notran_file "${converted_content}" "${file}"
}

#在Via支持正则表达式前先移除正则表达式，减少报错和资源占用。
function Remove_regex_Rules_for_via(){
local file="${1}"
test ! -f "${file}" && return
sed -i -E '/\\\//d;/\\\./d;/\\\?/d' "${file}"
}

#精简规则 去除Ublock不支持的规则
function lite_Uadblock_Rules(){
local file="${1}"
test ! -f "${file}" && return
local lite_content="$(grep -Ev \
 -e '^\/.*##' \
 -e '\$@?\$' \
 -e '#(@?%#)' \
 -e '#(@?\$\?)#' \
 -e '#\%#\/\/scriptlet' \
 -e '(\$|,)~?(dnsrewrite|replace)(,|=|$)' \
 -e ':(matches-property|nth-ancestor|-abp-properties)' \
 "${file}" | sort -u )"
write_notran_file "${lite_content}" "${file}"
}

#去除popup选定器，直接改用||域名^的形式。
function wipe_fiter_popup_domain(){
local file="${1}"
test ! -f "${file}" && return
sed -i -E \
  -e 's/\$popup,(~?third-party)$/\$\1/g' \
  -e 's/\$(~?third-party),popup$/\$\1/g' \
  -e 's/\$popup,(document|all)$//g' \
  -e 's/\$(document|all),popup$//g' \
  -e 's/\/\$(popup|document|all)$//g' \
  -e 's/\$(popup|document|all)$//g' \
  "${file}"
#sed -i -E '/^\|\|[0-9]+\.[0-9]+\./d' "${file}"
}

function count_filter_files() {
local _cf_file _cf_n _cf_div _cf_s _cf_q _cf_r
for _cf_file in "$@"
do
	[ -f "$_cf_file" ] && [ -r "$_cf_file" ] || continue
	_cf_n=$(wc -l < "$_cf_file" 2>/dev/null)
	case "$_cf_n" in ''|*[!0-9]*|0) continue ;; esac
	_cf_div="10000"; _cf_s="w"
	[ "$_cf_n" -lt "10000" ] && { _cf_div="1000"; _cf_s="k"; }
	[ "$_cf_n" -lt "1000" ] && { echo "$_cf_n"; continue; }
	_cf_q=$((_cf_n / _cf_div)); _cf_r=$((_cf_n % _cf_div))
	[ "$_cf_r" = "0" ] && echo "${_cf_q}${_cf_s}" || echo "${_cf_q}.$((_cf_r * 10 / _cf_div))${_cf_s}"
done
}

#更新README信息
function update_README_info(){
local file="`pwd`/README.md"
test -f "${file}" && rm -rf "${file}"
cat << key > "${file}"
# 混合规则
### 自动更新(`date +'%F %T'`)


| 名称 | 规则数量 | GIthub订阅链接 | Jsdelivrcdn缓存链接 | ~~GitCode订阅链接(死了)~~ | Gitlink订阅链接(竟然又活了) |
| :-- | :-- | :-- | :-- | :-- | :-- |
| 混合规则(自动更新) | $(count_filter_files `pwd`/Rules/adblock_auto.txt ) | [订阅](https://raw.githubusercontent.com/lingeringsound/adblock_auto/main/Rules/adblock_auto.txt) | [订阅](https://cdn.jsdelivr.net/gh/lingeringsound/adblock_auto@main/Rules/adblock_auto.txt) | ~~[订阅](https://gitcode.net/weixin_45617236/adblock_auto/-/raw/main/Rules/adblock_auto.txt)~~ | [订阅](https://cdn09022024.gitlink.org.cn/api/v1/repos/keytoolazy/adblock_auto/raw/Rules/adblock_auto.txt?ref=main&access_token=9aa2be1250ca725d0ef1b1f638fb3de408a11335) |
| 混合规则精简版(自动更新) | $(count_filter_files `pwd`/Rules/adblock_auto_lite.txt ) | [订阅](https://raw.githubusercontent.com/lingeringsound/adblock_auto/main/Rules/adblock_auto_lite.txt) | [订阅](https://cdn.jsdelivr.net/gh/lingeringsound/adblock_auto@main/Rules/adblock_auto_lite.txt) | ~~[订阅](https://gitcode.net/weixin_45617236/adblock_auto/-/raw/main/Rules/adblock_auto_lite.txt)~~ | [订阅](https://cdn09022024.gitlink.org.cn/api/v1/repos/keytoolazy/adblock_auto/raw/Rules/adblock_auto_lite.txt?ref=main&access_token=9aa2be1250ca725d0ef1b1f638fb3de408a11335) |


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
