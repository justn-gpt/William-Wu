# shell-scripts
test purpose (个人测试用)

虽然是个人测试，有的还是得说一下
sb_00.sh是为了解决s14的YouTube播放卡59秒问题和s15的twitch无法播放原画问题，这个脚本是魔改老王的，所以有事不要找他。

这个无交互版本的所有变量都是和老王原版的一样，但是多了两个变量SOCKSU和SOCKSP来设置socks5的用户名和密码。

另外socks5的端口就是原版里的VMESS_PORT变量端口，我去掉了没加速的vmess端口，拿给socks5用了，但是变量名字懒得改。

所以运行的命令大概就是：

VMESS_PORT=tcp端口 HY2_PORT=udp端口 TUIC_PORT=udp端口 bash <(curl -Ls https://github.com/Neomanbeta/shell-scripts/raw/refs/heads/main/sb_00.sh)
可选环境变量：UUID SOCKSU SOCKSP NEZHA_SERVER NEZHA_PORT NEZHA_KEY ARGO_DOMAIN ARGO_AUTH CFIP CFPORT
