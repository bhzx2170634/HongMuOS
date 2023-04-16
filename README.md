# HongMuOS
使用nasm编写的OS

## API
- 打印字符 <a href="https://github.com/bhzx2170634/HongMuOS#printstring">@printString</a>
- 读取磁盘 <a href=https://github.com/bhzx2170634/HongMuOS#readdisk>@readDisk</a>

### @printString
使用int 0x86调用
ax:0x0001
ebx:线性地址

### @readDisk
使用int 0x86调用
ax:0x0002
ebx:缓冲区线性地址
ecx:读取扇区数
edx:扇区起始扇区号
