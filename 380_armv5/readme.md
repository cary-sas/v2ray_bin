文件仅用upx压缩，此库供v2ray二进制更新使用，仅支持380固件，armv5，其他固件请自行使用upx压缩即可  
压缩命令: `upx --lzma --ultra-brute v2ray`  
备用命令: `upx -9 v2ray` 或者 `upx --best v2ray`  
Ubuntu :  `upx-ucl --lzma --ultra-brute v2ray`   
Ubuntu install upx-ucl:  `apt install upx-ucl`  
*if the latest version of upx-ucl has problem in output file, try this old version*  
 `wget http://archive.ubuntu.com/ubuntu/pool/universe/u/upx-ucl/upx-ucl_3.94-4_amd64.deb`   
 `dpkg -i upx-ucl_3.94-4_amd64.deb`   

 v26.5.9 开始，项目魔改并重新编译了 xray-core，删掉了用不到的模块和功能，增加并支持了 trojan-go ws 的功能
