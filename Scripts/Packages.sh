#!/bin/bash

#安装和更新软件包

UPDATE_PACKAGE() {

	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)

	local REPO_NAME=${PKG_REPO#*/}


	echo " "


	# 删除可能存在的冲突软件包

	for NAME in "${PKG_LIST[@]}"; do

		echo "Search directory: $NAME"

		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)


		if [ -n "$FOUND_DIRS" ]; then

			while read -r DIR; do

				rm -rf "$DIR"

				echo "Delete directory: $DIR"

			done <<< "$FOUND_DIRS"

		else

			echo "Not found directory: $NAME"

		fi

	done



	# 克隆软件包

	git clone --depth=1 --single-branch --branch $PKG_BRANCH \
	"https://github.com/$PKG_REPO.git"



	if [[ $PKG_SPECIAL == "pkg" ]]; then

		find ./$REPO_NAME/*/ -maxdepth 3 \
		-type d \
		-iname "*$PKG_NAME*" \
		-prune \
		-exec cp -rf {} ./ \;

		rm -rf ./$REPO_NAME/


	elif [[ $PKG_SPECIAL == "name" ]]; then

		mv -f $REPO_NAME $PKG_NAME

	fi

}



# ==========================
# 第三方软件包
# ==========================


# DAE
UPDATE_PACKAGE \
"luci-app-dae" \
"QiuSimons/luci-app-dae" \
"kix"



# ==========================
# 删除官方冲突包
# ==========================


rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,dae*,bypass*}

rm -rf ../feeds/packages/net/{dae*}



# ==========================
# 版本更新函数
# 保留，避免其他脚本调用异常
# ==========================


UPDATE_VERSION() {

	local PKG_NAME=$1
	local PKG_MARK=${2:-false}


	local PKG_FILES=$(find ./ ../feeds/packages/ \
	-maxdepth 3 \
	-type f \
	-wholename "*/$PKG_NAME/Makefile")


	if [ -z "$PKG_FILES" ]; then

		echo "$PKG_NAME not found!"

		return

	fi


	echo "$PKG_NAME version update has started!"



	for PKG_FILE in $PKG_FILES; do


		local PKG_REPO=$(grep -Po \
		"PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" \
		$PKG_FILE)


		local PKG_TAG=$(curl -sL \
		"https://api.github.com/repos/$PKG_REPO/releases" \
		| jq -r \
		"map(select(.prerelease == $PKG_MARK)) | first | .tag_name")



		local OLD_VER=$(grep -Po \
		"PKG_VERSION:=\K.*" "$PKG_FILE")


		local OLD_HASH=$(grep -Po \
		"PKG_HASH:=\K.*" "$PKG_FILE")



		local NEW_VER=$(echo $PKG_TAG \
		| sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')



		local NEW_URL=$(grep -Po \
		"PKG_SOURCE_URL:=\K.*" "$PKG_FILE")



		local NEW_HASH=$(curl -sL "$NEW_URL" \
		| sha256sum \
		| cut -d ' ' -f 1)



		echo "old version: $OLD_VER $OLD_HASH"

		echo "new version: $NEW_VER $NEW_HASH"



		if [[ $NEW_VER =~ ^[0-9].* ]] \
		&& dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then


			sed -i \
			"s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" \
			"$PKG_FILE"


			sed -i \
			"s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" \
			"$PKG_FILE"


		fi


	done

}
