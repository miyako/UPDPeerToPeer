# UDPソケット：ピアツーピア通信

Anouar Moustarih（4D Morocco 品質サポートエンジニア）

## 概要

UDP（User Datagram Protocol）は、TCP/IPプロトコルスイートに含まれる軽量でコネクションレスなトランスポート層プロトコルです。ハンドシェイクや再送を省くことで、信頼性よりも速度と低オーバーヘッドを優先しています。UDPはマルチキャストやブロードキャストで複数の受信者に効率よくデータを送信できるため、動画配信やゲームのように、ときどきパケットが失われても許容できるリアルタイムアプリケーションに適しています。UDP上に構築されたピアツーピア（P2P）システムは、この特性を分散型のピア検出に活かしています。各ノードが自身の存在を知らせるメッセージをブロードキャストし、中央の調整役なしにほかのノードを見つけることで、遅延とインフラの必要性を減らします。実際の用途としては、効率的なコンテンツ配信を行うBitTorrentのようなファイル共有ネットワーク、プレイヤーをすばやくマッチングするマルチプレイヤーゲーム、スマートホームでサービスを自動検出するIoTデバイスの連携、ローカルの参加者を見つけるビデオ会議アプリのようなコラボレーションツールなどがあり、いずれも動的な接続を扱いやすいUDPのシンプルさの恩恵を受けています。

## はじめに

このテクニカルノートでは、ピアツーピアのピア検出メカニズムの包括的な実装を詳しく説明します。中心となるのは、PeerDiscoveryクラスと、ローカルのプライベートネットワーク向けの補助メソッドです。このクラスは4DのUDPSocketクラスとUDPEventクラスを使用して、ブロードキャストによるアナウンス、プローブへの応答、イベント駆動のデータ受信を処理し、TTLによる削除（プルーニング）で自動的に期限切れとなるピアの共有コレクションを管理します。主な構成要素には、初期化と終了のライフサイクル管理、共有オブジェクトを安全に扱うピアの追加・更新ロジックがあります。継続的に動作するRunPeerDiscoveryワーカーと、タイムスタンプを整形するUtil_formatLastSeenと組み合わせることで、このシステムはサーバーや依存関係なしに、あらゆる4Dアプリケーションが同じネットワーク上のインスタンスを検出・追跡できるようにします。

## 前提条件と要件

### 前提条件

プロジェクトを起動する前に準備しておく必要がある事項です。

- 4D 20R10以降が必須です。UDPSocketクラスとUDPEventクラスは20R10で導入されました。
- アプリケーションのすべてのインスタンスが、同じローカルネットワーク／サブネット上で動作している必要があります（ブロードキャストが届くことが必要です）。
- 選択したUDPのピア検出用ポート（デフォルトは54321）について、すべてのマシンのファイアウォール、ウイルス対策ソフト、ネットワークポリシーが受信と送信の両方を許可している必要があります。
- 同じマシン上のほかのプロセスが、ピア検出用ポートをすでにバインドしていてはいけません（排他的バインド）。
- macOS／Windowsが、4Dアプリケーションにネットワークソケットを開くことを許可している必要があります（標準ユーザーの権限で十分です）。

### 要件

システムの実行中、満たされ続けている必要がある条件です。

- UDPのブロードキャストパケット（宛先255.255.255.255、または設定したブロードキャストアドレス）が、参加しているすべてのマシンに届く必要があります。
- ピア検出用ポートは、アプリケーションが動作している間ずっと開いており、ブロックされていない必要があります。

これらの前提条件と要件が満たされていれば、ピア検出システムはすぐに起動し、数秒以内にピアが表示されます。前提条件が欠けていたり要件が満たされなかったりすると、エラーを出さずに失敗するか、ランタイムエラーが発生します。

## ピア検出メカニズム

### クラスの概要

PeerDiscoveryクラスは、UDPブロードキャストを使用してローカルネットワーク内のピアを検出できるようにします。このクラスは、アナウンス、プローブ、削除を自動的に処理します。JSON形式のアナウンスとプローブを送受信することで動作します。ピアは共有コレクションに格納されるため、プロセスをまたいでアクセスできます。このメカニズムは、オーバーヘッドの少ないUDPに依存してピアを検出します。ブロードキャストにより、ランデブーサーバーなしでローカルネットワーク内から見つけられるようになります。プローブにより、アクティブなピアを維持します。TTLにより、古いエントリが残るのを防ぎます。共有要素により、プリエンプティブ実行に対応します。各関数は連携して、途切れなく動作します。

プロパティはクラスの状態を定義します。`listener`プロパティは、受信データ用のUDPSocketオブジェクトを保持します。`sender`プロパティは、送信するブロードキャストを管理します。`discoveryPort`プロパティはUDPポートを設定します（デフォルトは54321）。`broadcastAddress`プロパティは、ローカルブロードキャストの宛先として"255.255.255.255"を指定します。`peers`プロパティは、ピアオブジェクトの共有コレクションを格納します。各ピアオブジェクトはid、name、ip、port、lastSeen、infoを持ちます。`myInfo`プロパティは、ローカルピアのアナウンスデータを格納します。`peerTTL`プロパティは、期限切れまでの秒数を定義します（デフォルトは90）。`running`プロパティは、動作中かどうかを示します。`logText`プロパティはログを蓄積します。`probeInterval`プロパティは、プローブの頻度を秒単位で設定します（デフォルトは30）。

```4d
property listener : 4D.UDPSocket
property sender : 4D.UDPSocket
property discoveryPort : Integer
property broadcastAddress : Text
property peers : Collection  // collection of peer objects {id,name,ip,port,lastSeen,info}
property myInfo : Object  // the object we announce about ourselves
property peerTTL : Integer  // seconds after which a peer is considered gone
property running : Boolean
property logText : Text
property probeInterval : Integer
property closingSignal : 4D.Signal


shared Class constructor($options : Object)
    If (OB Is defined($options; "port"))
        This.discoveryPort:=OB Get($options; "port")
    Else
        This.discoveryPort:=54321
    End if
    If (OB Is defined($options; "broadcastAddress"))
        This.broadcastAddress:=OB Get($options; "broadcastAddress")
    Else
        This.broadcastAddress:="255.255.255.255"
    End if
    If (OB Is defined($options; "ttl"))
        This.peerTTL:=OB Get($options; "ttl")
    Else
        This.peerTTL:=90
    End if
    If (OB Is defined($options; "probeInterval"))
        This.probeInterval:=OB Get($options; "probeInterval")
    Else
        This.probeInterval:=30
    End if
    var $id : Text
    If (OB Is defined($options; "id"))
        $id:=OB Get($options; "id")
    Else
        $id:=Generate UUID()
    End if
    var $name : Text
    If (OB Is defined($options; "name"))
        $name:=OB Get($options; "name")
    Else
        $name:=System info.machineName
    End if
    var $servicePort : Integer
    If (OB Is defined($options; "servicePort"))
        $servicePort:=OB Get($options; "servicePort")
    Else
        $servicePort:=0
    End if
    var $version : Text
    If (OB Is defined($options; "version"))
        $version:=OB Get($options; "version")
    Else
        $version:=System info.osVersion
    End if
    This.myInfo:=New shared object("type"; "ANNOUNCE"; "id"; $id; "name"; $name; "port"; $servicePort; "version"; $version)
    This.peers:=New shared collection()
    This.running:=True
    This.logText:=""
    This.closingSignal:=New signal()
    var $socketHolder : Object:=New shared object()
    Use ($socketHolder)
        $socketHolder.listener:=Null
        $socketHolder.sender:=Null
        $socketHolder.endOfInitialization:=New signal
    End use
    CALL WORKER("p2pworker"; Formula($1._initSockets($2)); This; $socketHolder)
    $socketHolder.endOfInitialization.wait()
    This.listener:=$socketHolder.listener
    This.sender:=$socketHolder.sender


Function _initSockets($socketHolder : Object)
    Use ($socketHolder)
        $socketHolder.listener:=4D.UDPSocket.new(This.discoveryPort; This)
        $socketHolder.sender:=4D.UDPSocket.new(0; This)
    End use
    $socketHolder.endOfInitialization.trigger()


Function sendAnnouncement()
    var $json : Text
    $json:=JSON Stringify(This.myInfo)
    var $blob : Blob
    TEXT TO BLOB($json; $blob; UTF8 text without length)
    Use (This)
        This.logText:=This.logText+"["+Time string(Current time)+"] Sent ANNOUNCE\n"
    End use
    This.sender.send($blob; This.broadcastAddress; This.discoveryPort)


Function sendProbe()
    var $probe:=New shared object("type"; "PROBE"; "id"; This.myInfo.id)
    var $json : Text
    $json:=JSON Stringify($probe)
    var $blob : Blob
    TEXT TO BLOB($json; $blob; UTF8 text without length)
    Use (This)
        This.logText:=This.logText+"["+Time string(Current time)+"] Sent PROBE\n"
    End use
    This.sender.send($blob; This.broadcastAddress; This.discoveryPort)


Function onData($socket : 4D.UDPSocket; $event : 4D.UDPEvent)
    var $text : Text
    $text:=BLOB to text($event.data; UTF8 text without length)
    var $obj : Object
    $obj:=New object
    $obj:=JSON Parse($text)
    If (Type($obj)=Is object)
        var $msgType : Text
        If (OB Is defined($obj; "type"))
            $msgType:=OB Get($obj; "type")
        Else
            $msgType:=""
        End if
        var $senderId : Text
        If (OB Is defined($obj; "id"))
            $senderId:=OB Get($obj; "id")
            Use (This)
                This.logText:=This.logText+"["+Time string(Current time)+"] Received "+$msgType+" from "+$event.address+":"+String($event.port)+"\n"
            End use
        Else
            $senderId:=""
        End if
        If ($senderId=This.myInfo.id)
            return
        End if
        If ($msgType="ANNOUNCE")
            This.addOrRefreshPeer($obj; $event.address; $event.port)
        Else
            If ($msgType="PROBE")
                var $json : Text
                $json:=JSON Stringify(This.myInfo)
                var $blob : Blob
                TEXT TO BLOB($json; $blob; UTF8 text without length)
                This.sender.send($blob; $event.address; $event.port)
            Else
                If ($msgType="BYE")
                    This.removePeerById($senderId)
                End if
            End if
        End if
    End if


Function addOrRefreshPeer($peerObj : Object; $ip : Text; $port : Integer)
    var $id : Text
    If (OB Is defined($peerObj; "id"))
        $id:=OB Get($peerObj; "id")
    Else
        $id:=""
    End if
    If ($id="")
        return
    End if
    var $idx : Integer
    $idx:=-1
    var $i : Integer
    For ($i; 0; This.peers.length-1)
        If (This.peers[$i].id=$id)
            $idx:=$i
            break
        End if
    End for
    var $peerName : Text
    If (OB Is defined($peerObj; "name"))
        $peerName:=OB Get($peerObj; "name")
    Else
        $peerName:=""
    End if
    Use (This.peers)
        var $entry : Object
        $entry:=New shared object("id"; $id; "name"; $peerName; "ip"; $ip; "port"; $peerObj.port; "lastSeen"; Milliseconds)
        If ($idx#-1)
            This.peers[$idx]:=$entry
        Else
            This.peers.push($entry)
        End if
        var $info : Object
        $info:=New shared object("type"; $peerObj.type; "id"; $id; "name"; $peerName; "port"; $peerObj.port; "version"; $peerObj.version)
        $entry.info:=$info
    End use


Function removePeerById($id : Text)
    If ($id="")
        return
    End if
    var $i : Integer
    Use (This.peers)
        For ($i; 0; This.peers.length-1)
            If (This.peers[$i].id=$id)
                This.peers.remove($i; 1)
                break
            End if
        End for
    End use


Function prunePeers()
    var $now : Integer
    $now:=Milliseconds
    var $stillAlive : Collection
    $stillAlive:=New shared collection
    Use (This.peers)
        var $i : Integer
        For ($i; 0; This.peers.length-1)
            var $diff : Real
            $diff:=($now-This.peers[$i].lastSeen)/1000
            If ($diff<This.peerTTL)
                var $old : Object
                $old:=This.peers[$i]

                var $newInfo : Object
                $newInfo:=New shared object("type"; $old.info.type; "id"; $old.id; "name"; $old.name; "port"; $old.port; "version"; $old.info.version)

                var $newEntry : Object
                $newEntry:=New shared object("id"; $old.id; "name"; $old.name; "ip"; $old.ip; "port"; $old.port; "lastSeen"; $old.lastSeen; "info"; $newInfo)
                $stillAlive.push(OB Copy($newEntry; ck shared; $stillAlive))
            End if
        End for
        Use (This)
            This.peers:=$stillAlive.copy(ck shared; This)
        End use
    End use


Function stop()
    var $bye:=New shared object("type"; "BYE"; "id"; This.myInfo.id)
    var $json : Text
    $json:=JSON Stringify($bye)
    var $blob : Blob
    TEXT TO BLOB($json; $blob; UTF8 text without length)
    If (This.sender#Null)
        This.sender.send($blob; This.broadcastAddress; This.discoveryPort)
        Use (This)
            This.logText:=This.logText+"["+String(Current time)+"] Sent BYE\n"
        End use
    Else
        Use (This)
            This.logText:=This.logText+"["+String(Current time)+"] Skipped BYE send (sender not initialized)\n"
        End use
    End if
    This.closingSignal:=New signal()


Function getPeers() : Collection
    return This.peers.copy(ck shared)
```

### コンストラクター

共有コンストラクターは、optionsオブジェクトを受け取ります。コンストラクターは、optionsからport、broadcastAddress、ttl、probeIntervalを処理します。optionsにキーがない場合は、デフォルト値が適用されます。idがない場合、コンストラクターはUUIDを生成します。nameが指定されていない場合は、マシン名が使われます。サービスポートのデフォルトは0です。versionがない場合は、OSのバージョンが設定されます。コンストラクターは、typeが"ANNOUNCE"の共有オブジェクトとしてmyInfoを作成します。peersは共有コレクションとして初期化されます。runningはTrueに設定されます。logTextは空で始まります。ワーカーに渡すために、socketHolder共有オブジェクトを準備します。コンストラクターは、ソケットを初期化するためにワーカーを呼び出します。

endOfInitializationシグナルで待機します。listenerとsenderは、socketHolderから代入されます。

### _initSockets

_initSockets関数はソケットを作成します。この関数はsocketHolderを使用します。listenerはdiscoveryPortにバインドします。senderはポート0を使用します。シグナルをトリガーして完了を通知します。

### sendAnnouncement

sendAnnouncement関数は、myInfoをブロードキャストします。myInfoをJSON文字列に変換します。テキストをBLOBに変換します。ログに"Sent ANNOUNCE"を追加します。senderが、broadcastAddressのdiscoveryPortに送信します。

### sendProbe

sendProbe関数は、プローブメッセージを送信します。プローブオブジェクトは、type "PROBE"とidを持ちます。プローブをJSON文字列に変換します。テキストからBLOBを作成します。ログに"Sent PROBE"を追加します。senderが、アドレスとポートにブロードキャストします。

### onData

onData関数は、UDPイベントを処理します。BLOBをテキストに変換します。JSONを解析してobjに格納します。objがオブジェクト型かどうかを確認します。msgTypeをobj.typeから取り出します。senderIdをobj.idから取り出します。アドレスとポートとともに受信をログに記録します。senderIdがローカルのidと一致する場合、関数は処理を終えます。"ANNOUNCE"の場合は、obj、アドレス、ポートを渡してaddOrRefreshPeerを呼び出します。"PROBE"の場合は、送信元にmyInfoを送り返します。"BYE"の場合は、senderIdを渡してremovePeerByIdを呼び出します。

### addOrRefreshPeer

addOrRefreshPeer関数は、ピアを更新します。peerObjからidを取り出します。idが空の場合、関数は処理を終えます。peersの中から、一致するidのインデックスを検索します。peerObj.nameからpeerNameを取り出します。Useブロックでpeersをロックします。id、name、ip、peerObj.port、lastSeen（Milliseconds）を持つ共有オブジェクトとしてエントリを作成します。インデックスに応じて、エントリを代入するか追加します。type、id、name、port、versionを持つinfoを、共有オブジェクトとして作り直します。infoをentry.infoに代入します。

### removePeerById

removePeerById関数は、ピアを削除します。idが空の場合、関数は処理を終えます。Useブロックでpeersをロックします。ループで一致するidを探します。そのインデックスを指定してremoveを呼び出します。

### prunePeers

prunePeers関数は、古くなったピアを取り除きます。nowにMillisecondsを設定します。stillAliveを共有コレクションとして初期化します。Useブロックでpeersをロックします。ループで、diffを(now - lastSeen)/1000として計算します。diffがpeerTTL未満の場合、oldにピアをコピーします。old.infoから、newInfoを共有オブジェクトとして作り直します。oldのデータとnewInfoから、newEntryを共有オブジェクトとして作成します。newEntryのコピーをstillAliveに追加します。stillAliveのコピーをpeersに代入します。

### stop

stop関数は、ピア検出を終了します。byeオブジェクトは、type "BYE"とidを持ちます。byeをJSON文字列に変換します。BLOBを作成します。senderがNullでなければ送信します。ログに"Sent BYE"、またはスキップしたことを示すメッセージを追加します。バックグラウンドのワーカーはプローブの送信を止め、ソケットを閉じます

### getPeers

getPeers関数は、peersのコピーを返します。*.copy*はck sharedを使います。

## 補助プロジェクトメソッド

### 概要

ピア検出システムは、2つの専用プロジェクトメソッドで完成します。RunPeerDiscoveryは、ピア検出を動作させ続けるバックグラウンドのワーカーとして動作します。Util_formatLastSeenは、生のタイムスタンプをユーザーインターフェース用の読みやすい文字列に変換します。これらのメソッドはPeerDiscoveryクラスの外で動作しますが、欠かせないものです。RunPeerDiscoveryは、ワーカーで一度だけ実行されます。Util_formatLastSeenはリストボックスの列の式から呼び出され、自動更新とわかりやすい「〜前」の表示を実現します。

### RunPeerDiscovery

```4d
#DECLARE($options : Object)

var $discovery : cs.PeerDiscovery
$discovery:=cs.PeerDiscovery.new($options)


Use (Storage)
    Storage.discovery:=$discovery  // Share instance
    Storage.peers:=New shared collection
    Storage.logText:=New shared object("value"; "")
End use


While (Not($discovery.closingSignal.wait(5)))

    $discovery.sendProbe()
    $discovery.prunePeers()
    Use (Storage)
        Storage.peers:=$discovery.getPeers()  //.copy(ck shared)
        Use (Storage.logText)
            Storage.logText.value:=$discovery.logText
        End use
    End use

End while


Use (Storage)
    Storage.discovery:=Null
    Storage.peers:=New shared collection
    Storage.logText:=New shared object("value"; "")
End use
```

RunPeerDiscoveryメソッドは、optionsオブジェクトを入力として受け取ります。このメソッドは、新しいシグナルオブジェクトを作成します。シグナルは、連携のためにoptions.signalに代入されます。optionsを渡してPeerDiscoveryインスタンスを初期化します。共有のStorageを、ピア検出のインスタンスで更新します。Storage.peersに新しい共有コレクションを設定します。Storage.logTextを、空のvalueを持つ共有オブジェクトとして初期化します。

シグナルがトリガーされていない間、ループが実行されます。ピア検出のインスタンスを通じてプローブを送信します。削除処理で期限切れのピアを取り除きます。getPeersから取得したコピーでStorage.peersを更新します。入れ子になったUseブロックの中で、ピア検出のインスタンスのlogTextをlogText.valueに代入します。5*60ティックを使って、プロセスを30秒間待機させます。

終了シグナルを受けると、このメソッドはピア検出のインスタンスを停止します。discoveryをNullにし、peersとlogTextをリセットして、Storageをクリアします。

### Util_formatLastSeen

```4d
#DECLARE($lastSeen : Integer)->$formatted : Text

var $diff : Real:=(Milliseconds-$lastSeen)/1000  // Seconds elapsed

Case of
    : ($diff<60)
        $formatted:=String(Round($diff; 1))+" seconds ago"
    : ($diff<3600)
        $formatted:=String($diff\60)+" minutes ago"
    : ($diff<86400)
        $formatted:=String($diff\3600)+" hours ago"
End case
```

Util_formatLastSeenメソッドは、Integer型の入力としてlastSeenを、Text型の出力としてformattedを宣言します。diffは、MillisecondsからlastSeenを引き、1000で割った秒数として計算されます。

![](fig-01)

## デモアプリケーション

アプリケーションは、バージョン20R10以降で起動する必要があります。

初期化されると、プローブの処理が自動的に始まり、プローブのイベントはそれぞれアプリケーションのログに書き込まれます。

「アナウンス」ボタンをクリックすると、アナウンスメッセージが生成されます。このメッセージは、プローブのイベントと同じログの仕組みで処理されます。

「ローカル情報」フィールドには、ローカルピアの属性が表示されます。これらの属性は、ピアとして動作しているホストマシンのシステム情報に対応しています。

ピアのリストは継続的に同期されます。古くなったピアは削除され、新しく検出されたピアが追加されます。どちらの処理もバックグラウンドで実行され、すべてPeerDiscoveryクラスによって制御されます。

「閉じる」ボタンは、ローカルネットワーク上のピア検出を終了します。この操作を行ったピアは、アクティブなピア検出から外されます。

## まとめ

PeerDiscoveryクラスは、ネイティブの4Dだけで完結するピアツーピアのピア検出ソリューションを提供します。UDPSocketクラスとUDPEventクラスを活用することで、真に非同期でイベント駆動のUDP通信を実現しています。

この実装には、外部ライブラリも、ランデブーサーバーも、手動での設定も必要ありません。起動するとすぐに、4Dアプリケーションは同じローカルネットワーク上で実行中のほかのすべてのインスタンスをリアルタイムで把握できるようになります。TTLにもとづく自動削除によってピアのリストは正確に保たれ、正常終了時のBYEメッセージによって消えたピアが残ることを防ぎ、付属の整形メソッドによってユーザーインターフェースにすっきりと表示できます。

このソリューションは、分散型のツール、デスクトップのコラボレーションアプリケーション、ローカルの同期サービスなど、サーバーを使わずにインスタンスをすばやく連携させる必要があるあらゆる場面で、特に役立ちます。
