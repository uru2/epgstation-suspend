# EPGStationでサスペンドしたい

[EPGStation](https://github.com/l3tnun/EPGStation) + [mirakc](https://github.com/mirakc/mirakc) の組み合わせで予約録画まで間があるときに積極的にサスペンドします。


## 注意!!

- そもそもの話として[**サスペンド運用は非推奨**](https://github.com/l3tnun/EPGStation/issues/419#issuecomment-786386437)です
- Mirakurunではその挙動から問題となる可能性があります
- ここに示しているのはあくまでも作者環境での実装例ですので、**他の環境での動作保証はしません**


## こんな感じの動作

1. システム起動10分後から10分おきにサスペンドするかどうかチェック
2. 以下条件のどれかに当てはまる場合にはサスペンドしないでそのままチェックを抜ける
    - 誰かがターミナル等でログイン中
    - 録画ファイル(*.m2ts)にアクセス中
    - チューナーデバイス利用中
        - よく使われるであろうデバイスはとりあえず指定しておきました
    - ffmpeg実行中
    - 録画中
    - 20分以内に録画予定あり
    - サスペンド時間が10分以下
3. 復帰時刻は直近録画予定の2分前にしてサスペンド
4. 復帰後にNTPでシステムクロック同期とEPGStationのタイマーリセット
    - Wake-on-LANなどで強制復帰した場合も同様


## 動作確認環境

- Debian 11 amd64
    - 以下パッケージを利用
        - lsof
        - chrony
        - curl
        - jq
- EPGStation 2.*
- mirakc 3.*


## インストール

```
# apt-get install lsof chrony curl jq

# cp suspend.sh /usr/local/sbin
# chmod +x /usr/local/sbin/suspend.sh
# cp resume.sh /usr/local/sbin
# chmod +x /usr/local/sbin/resume.sh

# cp suspend.service /etc/systemd/system
# cp suspend.timer /etc/systemd/system
# cp resume.service /etc/systemd/system

# systemctl enable suspend.service
# systemctl enable suspend.timer
# systemctl enable resume.service
```


## 設定変更したい

- サスペンドチェック間隔を変えたい
    - [suspend.timer](suspend.timer) の ```OnUnitActiveSec```
- 次回予約が20分以上あるかどうかの時間を変えたい
    - [suspend.sh](suspend.sh) の ```NEXT_REC_START_MARGIN_SECOND```
- 復帰が直近録画予定の2分前なのをもっと余裕を持たせたい
    - [suspend.sh](suspend.sh) の ```NEXT_REC_START_BEFORE_SECOND```
- 特定プロセス実行中ならサスペンドしたくない
    - [suspend.sh](suspend.sh) の ```if pgrep ffmpeg; then``` 付近を参考に


## 何でrtcwake使ってサスペンドしないの?

systemdでは自身の機能以外でのサスペンド実行では復帰後のunit実行の面倒を見てくれません。  
resume.sh が実行されないのは致命的です。


## おまけ

[px4_drv](https://github.com/nns779/px4_drv)を組み込んだままサスペンドすると復帰不能となってしまったので、サスペンド直前にpx4_drvをアンロードし復帰直後にロードし直すunit作りました。

```
# cp px4-sleep.service /etc/systemd/system
# systemctl enable px4-sleep.service
```


##  作った人
[うる。](https://github.com/uru2)


## ライセンス
[MIT License](LICENSE)
