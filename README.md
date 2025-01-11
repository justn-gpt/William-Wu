# shell-scripts
test purpose (个人测试用)

虽然是个人测试，有的还是得说一下
sb_00.sh是为了解决s14的YouTube播放卡59秒问题和s15的twitch无法播放原画问题（喜报：S15在12月27号炸机过后，已经可以正常播放twitch了，不再需要这个脚本了），这个脚本是魔改老王的，所以有事不要找他。

这个无交互版本是魔改老王的四合一版本，所以现在很多地方不一样了，包括变量。

比起老王的版本，这个你只需要面板里开启一个TCP端口和一个UDP端口，给你节省一个端口，你可以留着干别的去用。

脚本去掉了哪吒，换成了Beszel的监控客户端，所以多了一个BESZEL_KEY的变量，但是注意这个变量的值并不是Beszel面板里直接复制的那串，而是去掉了前面ssh-ed25519只需要后面的部分，如果你要用，要注意。

还有一个需要注意的是，这个脚本在开始运行的时候会对当前serv00服务器的三个入口做连通性检测，必须起码有两个IP连通性检测结果是(通)，这个脚本才会运行正常，不过我的serv00都是有两个入口国内是通的，所以我就没有在脚本里写不满足条件时候的判断(懒)。

魔改版本去掉了vmess改成了vless，所以脚本运行后提供的所有协议为 socks5|vless-ws-tls(argo)|hysteria2|tuic 

这个魔改脚本所有的变量是TCP_PORT UDP_PORT 可选变量： UUID BESZEL_KEY SOCKSU SOCKSP ARGO_DOMAIN ARGO_AUTH CFIP CFPORT

TCP_PORT=TCP端口号 UDP_PORT=UDP端口号 bash <(curl -Ls https://github.com/Neomanbeta/shell-scripts/raw/refs/heads/main/sb_00.sh)
