iscsi-multipath on KVM 環境作成スクリプト
=========================================

CentOS7 を使用して4パスのiscsi-multipath環境を作成するスクリプトです。
KVMホスト上に一時的なローカルネットワークを4つ作成して、それら4つのネットワーク
に接続しているinitiatorとtargetのゲストを作成します。
CentOS7もしくはFedora20をインストールしたマシンでKVMとvirt-installが使えること
を前提としています。以下のの順序でセットアップを実行してください。

### ゲストセットアップ ###
ゲスト用ネットワーク作成とゲスト作成用スクリプトの生成。

	# sh ./make-create-scripts.sh

target作成(ゲスト名:target)

	# ./create-target.sh

targetインストール完了後、ユーザ:**root** パスワード:**password**でログインして以下を実行。

	# target-setup.sh

initiator作成(ゲスト名:initiator)

	# ./create-initiator.sh

initiatorインストール完了後、ユーザ:i**root** パスワード:**password** でログインして以下を実行。

	# initiator-setup.sh

### 完了 ###
上記手順が正常に完了すると、multibus4パスの1GBデバイスがinitiatorの/mnt/iscsiに
マウントされた状態になっている。

クリーンアップ
==============
initiatorをインストール完了状態に戻すには以下のコマンドを実行。

	# initiator-cleanup.sh

targetをインストール完了状態に戻すには以下のコマンドを実行。

	# target-cleanup.sh

ゲストセットアップ前の状態に戻すには以下のコマンドを実行。

	# ./cleanup-initiator.sh
	# ./cleanup-target.sh
	# ./create-initiator.sh
	# ./remove-tmp_files.sh
	# rm -f ./remove-tmp_files.sh
