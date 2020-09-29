#!/bin/bash
# 检查插件是否在当前平台下
function doesSupportAndroidPlatform() {
  if [ -f "${1}android/build.gradle" ];then
    echo 0
  else
    echo 1
  fi
}
# 版本自动升级
function updateVersion() {
  v=$(grep VERSION_NAME configs/gradle.properties|cut -d'=' -f2)
  echo 旧版本号$v
  v1=$(echo | awk '{split("'$v'",array,"."); print array[1]}')
  v2=$(echo | awk '{split("'$v'",array,"."); print array[2]}')
  v3=$(echo | awk '{split("'$v'",array,"."); print array[3]}')
  y=$(expr $v3 + 1)

  if [ $y -ge 10 ];then
    y=$(expr $y % 10)
    v2=$(expr $v2 + 1)
  fi

  if [ $v2 -ge 10 ];then
    v2=$(expr $v2 % 10)
    v1=$(expr $v1 + 1)
  fi

  vv=$v1"."$v2"."$y
  echo 新版本号$vv
  # 更新配置文件 mac强制需要加备份文件
  a=`uname  -a`
  if [[ $a =~ "Darwin" ]];then
    sed -i '' 's/VERSION_NAME='$v'/VERSION_NAME='$vv'/g' configs/gradle.properties
  else
    sed -i 's/VERSION_NAME='$v'/VERSION_NAME='$vv'/g' configs/gradle.properties
  fi

  if [ $? -eq 0 ]; then
      echo '更新版本号成功...'
  else
      echo '更新版本号失败...'
      exit
  fi
}
# 初始化记录项目pwd
projectDir=$(pwd)
cd ${projectDir}
# 根据情况设置版本
num=$#
if [ $num -eq 0 ];then
  updateVersion
else
  v=$(grep VERSION_NAME configs/gradle.properties|cut -d'=' -f2)
  sed -i 's/VERSION_NAME='$v'/VERSION_NAME='$1'/g' configs/gradle.properties
  if [ $? -eq 0 ]; then
      echo '更新版本号成功...'
  else
      echo '更新版本号失败...'
      exit
  fi
fi
# step1 clean
echo 'clean old build'
cd ${projectDir}
flutter clean

# step 2 package get generate .android .ios
echo 'packages get'
cd ${projectDir}
flutter packages get

# step3 脚本补充：因为.android是自动编译的，所以内部的配置文件和脚本不可控，所以需要将configs内的脚本自动复制到 .android 内部
echo 'copy configs/.android/config/... '
if [  -d '.android/config/' ]; then
   echo '.android/config 文件夹已存在'
else :
   mkdir .android/config
fi

# step 4  覆盖build.gradle gradle.properties
cp configs/gradle.properties .android/gradle.properties
cp configs/flutter_jfrog.gradle .android/config/flutter_jfrog.gradle
cp configs/build.gradle .android/build.gradle

# step 5 各个plugin单独打包
# shellcheck disable=SC2013
# shellcheck disable=SC2002
for line in $(cat .flutter-plugins | grep -v '^ *#')
do
    plugin_name=${line%%=*}
    plugin_path=${line##*=}
    res=$(doesSupportAndroidPlatform ${plugin_path})
    if [ $res -eq 0 ];then
      echo '==Build and publish plugin: ['"${plugin_name}"']='"${plugin_path}"
      cd .android || exit
      echo "==start build release aar for plugin [""${plugin_name}""]"
      ./gradlew "${plugin_name}":clean
      ./gradlew "${plugin_name}":assembleRelease
      echo "==start upload maven for plugin [""${plugin_name}""]"
      ./gradlew "${plugin_name}":artifactoryPublish
      printf "done\n"
      cd ../
    fi
done

cd .android

echo "==start build release aar for [moduleflutter]"
./gradlew clean assembleRelease

echo "==start upload maven for [moduleflutter]"
./gradlew flutter:artifactoryPublish

echo '<<<<<<<<<<<<<<<<<<<<<<<<<< 结束 >>>>>>>>>>>>>>>>>>>>>>>>>'
exit
