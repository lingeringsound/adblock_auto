#!/bin/sh

#加载公共函数
source "`pwd`/until_function.sh"

#指定目录和输出文件
Temple_base_Folder="`pwd`/temple_full"
Sort_Folder="$Temple_base_Folder/sort" 
Download_Folder="$Temple_base_Folder/download_Rules"
Combine_Folder="$Temple_base_Folder/combine"
Rules_Folder="`pwd`/Rules"
Base_Rules_Folder="`pwd`/base"

#删除缓存?(也许)
rm -rf "${Rules_Folder}/adblock_auto.txt" "$Temple_base_Folder" 2>/dev/null

#创建目录
mkdir -p "${Download_Folder}" "${Sort_Folder}/lite" "${Combine_Folder}/lite" "${Rules_Folder}" && echo "※`date +'%F %T'` 创建临时目录成功！"

#设置权限
chmod -R 777 "`pwd`"

#下载规则
download_link "${Download_Folder}"

#处理规则
#Easylist 公共规则
echo "※`date +'%F %T'` 开始处理Easylist规则……"
wipe_white_list "${Sort_Folder}" "${Download_Folder}/easylistchina.txt" '^\@\@|^[[:space:]]\@\@\|\||^<<|<<1023<<|^\@\@\|\||^\|\|'
add_rules_file "${Sort_Folder}" "${Download_Folder}/easylistchina.txt" '^\|\|.*\^$'
sort_adblock_Rules "${Sort_Folder}" "${Download_Folder}/easylist.txt" '^##|^###|^\/|\/ad\/|^:\/\/|^_|^\?|^\.|^-|^=|^:|^~|^,|^&'
sort_web_rules "${Sort_Folder}" "${Download_Folder}/easylist.txt" 

#full规则
echo "※`date +'%F %T'` 开始处理完整版规则……"
wipe_white_list "${Sort_Folder}" "${Download_Folder}/Adguard_Chinese.txt" '^\@\@|^[[:space:]]\@\@\|\||^<<|<<1023<<|\@\@\|\|'
wipe_white_list "${Sort_Folder}" "${Download_Folder}/adguard_optimized.txt" '^\@\@|^[[:space:]]\@\@\|\||^<<|<<1023<<|\@\@\|\|'
sort_adblock_Rules "${Sort_Folder}" "${Download_Folder}/Adguard_mobile.txt" '^##|^###|^\/|\/ad\/|^:\/\/|^_|^\?|^\.|^-|^=|^:|^~|^,|^&|^\|\||^#\$#|^#\?#'
sort_web_rules "${Sort_Folder}" "${Download_Folder}/Adguard_mobile.txt"
sort_adblock_Rules "${Sort_Folder}" "${Download_Folder}/easylist_adservers_popup.txt" '^\|\|'
#去除转换popup选定器，直接改用||域名^的形式。
wipe_fiter_popup_domain "${Sort_Folder}/easylist_adservers_popup.txt"

#合并规则
echo "※`date +'%F %T'` 开始合并规则……"
#Full
Combine_adblock_original_file "${Combine_Folder}/adblock_combine.txt" "${Sort_Folder}"
#复制补充规则
cp -rf "${Base_Rules_Folder}/adblock" "${Combine_Folder}/adblock.txt"
cp -rf "${Base_Rules_Folder}/其他.prop" "${Combine_Folder}/其他.txt"
cp -rf "${Base_Rules_Folder}/去除小说广告.prop" "${Combine_Folder}/去除小说广告.txt"
cp -rf "${Download_Folder}/antiadblockfilters.txt" "${Combine_Folder}/antiadblockfilters.txt"
cp -rf "${Base_Rules_Folder}/常用广告的顶级域名.prop" "${Combine_Folder}/常用广告的顶级域名.txt"
cp -rf "${Base_Rules_Folder}/拦截H转跳.prop" "${Combine_Folder}/拦截H转跳.txt"
cp -rf "${Base_Rules_Folder}/网址批量规则.prop" "${Combine_Folder}/网址批量规则.txt"
cp -rf "${Base_Rules_Folder}/youtube.prop" "${Combine_Folder}/youtube.txt"
cp -rf "${Base_Rules_Folder}/反Adblock.prop" "${Combine_Folder}/反Adblock.txt"

#去除完整版规则不必要的"拦截H转跳"
sed -Ei '/\$~third-party/d' "${Combine_Folder}/拦截H转跳.txt"

#合并预处理规则
Combine_adblock_original_file "${Rules_Folder}/adblock_auto.txt" "${Combine_Folder}"

#规则小修
fix_Rules "${Rules_Folder}/adblock_auto.txt" '\$popup,domain=racaty\.io,0123movie\.ru' '\$popup,domain=racaty\.io\|0123movie\.ru'
fix_Rules "${Rules_Folder}/adblock_auto.txt" '##aside:-abp-has' '#\?#aside:-abp-has'
fix_Rules "${Rules_Folder}/adblock_auto.txt" '##tr:-abp-has' '#\?#tr:-abp-has'
fix_Rules "${Rules_Folder}/adblock_auto.txt" '\$~media,~subdocument,third-party,domain=mixdrp\.co,123movies\.tw\|' '\$~media,~subdocument,third-party,domain=mixdrp\.co\|123movies\.tw\|'
fix_Rules "${Rules_Folder}/adblock_auto.txt" '\$third-party,script,_____,domain=' '\$third-party,script,domain='
fix_Rules "${Rules_Folder}/adblock_auto.txt" ',_____,domain=' ',domain='
fix_Rules "${Rules_Folder}/adblock_auto.txt" ':-abp-has(' ':has('
#fix_Rules "${Rules_Folder}/adblock_auto.txt" ' { remove: true; }' ':remove()'
fix_Rules "${Rules_Folder}/adblock_auto.txt" ':-abp-contains(' ':has-text('

#净化去重规则
modtify_adblock_original_file "${Rules_Folder}/adblock_auto.txt"
#去除badfilter冲突规则
wipe_badfilter "${Rules_Folder}/adblock_auto.txt"
#去除Ublock不支持的规则
lite_Uadblock_Rules "${Rules_Folder}/adblock_auto.txt"
#adblock限定器缩写改成全名，兼容部分读取不到缩写的浏览器
convert_abbreviations "${Rules_Folder}/adblock_auto.txt"
#读取白名单 剔除规则
make_white_rules "${Rules_Folder}/adblock_auto.txt" "`pwd`/white_list/white_list.prop"
#剔除冲突的CSS规则
fixed_css_white_conflict "${Rules_Folder}/adblock_auto.txt"
#去除重复作用域名
Running_sort_domain_Combine "${Rules_Folder}/adblock_auto.txt"
#去除指定重复的Css
Running_sort_Css_Combine "${Rules_Folder}/adblock_auto.txt"
#修复低级错误
fixed_Rules_error "${Rules_Folder}/adblock_auto.txt"
#再次净化去重
modtify_adblock_original_file "${Rules_Folder}/adblock_auto.txt"
#规则分类
sort_and_optimum_adblock "${Rules_Folder}/adblock_auto.txt"
#写入头信息
write_head "${Rules_Folder}/adblock_auto.txt" "混合规则(更新日期`date '+%F %T'`)" "合并于各种知名的Adblock规则,适用于 Adguard / Ublock Origin / Adblock Plus(用Adblock Plus源码编译的软件也支持，例如嗅觉浏览器 ) 支持复杂语法的过滤器，或者能兼容大规则的浏览器例如 X浏览器" && echo "※`date +'%F %T'` 混合规则合并完成！"

rm -rf "$Temple_base_Folder"
#更新README信息
update_README_info && echo "※`date +'%F %T'` 完成信息更新！"

exit 0
