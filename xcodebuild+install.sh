#! bin/bash
###############配置项目名称和路径等相关参数
projectName="PinkDiary" #项目所在目录的名称
isWorkSpace=false  #判断是用的workspace还是直接project，workspace设置为true，否则设置为false
projectDir=~/work/$projectName #项目所在目录的绝对路径
buildConfig="CWeb" #编译的方式,默认为Release,还有Debug等

###############配置下载的文件名称和路径等相关参数
appName="粉粉日记"  #在网页上显示的名字
wwwIPADir=~/Documents/www/pd/ #html，ipa，icon，plist最后所在的目录绝对路径
url="http://192.168.1.115/pd" #下载路径

##########################################################################################
##############################以下部分为自动生产部分，不需要手动修改############################
##########################################################################################

###############检查html等文件放置目录是否存在，不存在就创建
echo "开始编译................"
echo "当前编译模式为:$buildConfig"
echo "开始目录检查........"

if [ -d "$wwwIPADir" ]; then
	echo "文件目录存在"
else 
	echo "文件目录不存在"
    mkdir -pv $wwwIPADir
	echo "创建${wwwIPADir}目录成功"
fi

###############进入项目目录
cd $projectDir
rm -rf ./build
buildAppToDir=$projectDir/build #编译打包完成后.app文件存放的目录

###############获取版本号,bundleID
infoPlist="$projectName/$projectName-Info.plist"
bundleVersion=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $infoPlist`
bundleIdentifier=`/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" $infoPlist`
bundleBuildVersion=`/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $infoPlist`

###############开始编译app
if $isWorkSpace ; then  #判断编译方式
    echo  "开始编译workspace...."
    xcodebuild  -workspace $projectName.xcworkspace -scheme $projectName  -configuration $buildConfig clean build SYMROOT=$buildAppToDir
else
    echo  "开始编译target...."
    xcodebuild  -target  $projectName  -configuration $buildConfig clean build SYMROOT=$buildAppToDir
fi
#判断编译结果
if test $? -eq 0
then
echo "===================编译成功==================="
else
echo "~~~~~~~~~~~~~~~~~~~编译失败~~~~~~~~~~~~~~~~~~~"
exit 1
fi

###############开始打包成.ipa
ipaName=`echo $projectName | tr "[:upper:]" "[:lower:]"` #将项目名转小写
appDir=$buildAppToDir/$buildConfig-iphoneos/  #app所在路径
echo "开始打包$projectName.app成$projectName.ipa....."
xcrun -sdk iphoneos PackageApplication -v $appDir/$projectName.app -o $appDir/$ipaName.ipa #将app打包成ipa

###############开始拷贝到目标下载目录
iconName="icon.png" #icon名称
iconSize=100 #icon大小
#unzipAppDir=$appDir/$projectName.app
unzipAppDir=$projectDir
iconImages=($(find $unzipAppDir -path "$buildAppToDir" -prune -o -type f -size +1k -name "*[iI]con*.png" |xargs ls -lSar| grep ^-)) #查找带Icon或icon的图标，取最大的图片,忽略build目录，按大小排序输出
#iconImages=($(find $unzipAppDir -size +1k -name "*[iI]con*.png")) #查找带Icon或icon的图标，取最大的图片
iconImagesLength=${#iconImages[@]} #获取数组的count
cp -f -p ${iconImages[iconImagesLength-1]} $wwwIPADir/$iconName  #拷贝icon.png文件

#检查文件是否存在
if [ -f "$appDir/$ipaName.ipa" ]
then
echo "打包$ipaName.ipa成功."
else
echo "打包$ipaName.ipa失败."
exit 1
fi
cp -f -p $appDir/$ipaName.ipa $wwwIPADir/$ipaName.ipa   #拷贝ipa文件
echo "复制$ipaName.ipa到${wwwIPADir}成功"

###############计算文件大小和最后更新时间
fileSize=`stat $appDir/$ipaName.ipa |awk '{if($8!=4096){size=size+$8;}} END{print "文件大小:", size/1024/1024,"M"}'`
lastUpdateDate=`stat $appDir/$ipaName.ipa | awk '{print "最后更新时间:",$13,$14,$15,$16}'`
echo $fileSize
echo $lastUpdateDate

plistDir=${wwwIPADir}/$ipaName.plist #plist文件的路径
htmlDir=${wwwIPADir}/index.html #html文件的路径

###############生成PLIST文件
cat << EOF > $plistDir
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	<dict>
		<key>items</key>
		<array>
			<dict>
				<key>assets</key>
				<array>
					<dict>
						<key>kind</key>
						<string>software-package</string>
						<key>url</key>
	          <string>$url/$ipaName.ipa</string>
					</dict>
				</array>
				<key>metadata</key>
				<dict>
					<key>bundle-identifier</key>
	        <string>$bundleIdentifier</string>
					<key>bundle-version</key>
					<string>$bundleVersion</string>
					<key>kind</key>
					<string>software</string>
					<key>title</key>
					<string>$appName</string>
				</dict>
			</dict>
		</array>
	</dict>
	</plist>
EOF

###############生成html下载页面
cat << EOF > $htmlDir
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
          <meta id="viewport" name="viewport" content="width=device-width; height=device-height; initial-scale=1.0; "/>
          <title>安装$appName</title> 
          <style type="text/css">
          </style>
        </head> 
        <body> 
          <h2>$appName</h2>
          <img src="./$iconName" width=$iconSize height = $iconSize>
          <ul>    
            <li>
              <h2><a href="itms-services://?action=download-manifest&amp;url=$url/$ipaName.plist">安装$appName(V$bundleVersion.$bundleBuildVersion)</a></h2>
            </li>
          </ul>
          <p>
            $fileSize
          <p>
            $lastUpdateDate
        </body>
      </html>
EOF