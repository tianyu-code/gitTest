    org 07c00h ; 告诉BIOS程序加载到7c00处，我们编译好的二进制文件烧写进了镜像img中的0扇区的512字节内，注意这是
    ;文件存放位置，bios结束后会找启动文件的0扇区处，而org是告诉编译器，我的程序执行时的绝对物理地址是07c00，h代表16进制

BaseOfStack equ 07c00h  ; 堆栈基地址（栈底, 从这个位置向低地址生长），
                        
%include	"load.inc"
;================================================================================================

    jmp short LABEL_START ; Start to boot. 
    nop ; 这个nop 不可少 

; 下面是 FAT12 磁盘的头
%include	"fat12hdr.inc"




; 程序开始的地方，注意变量定义一定要在汇编代码之前或者之后，因为程序是按着地址递增来执行的，遇到变量那就是错误的指令

LABEL_START: 

    mov ax, cs 
    mov ds, ax  ;数据段指向代码段
    mov es, ax  ;附加数据段指向代码段
    mov ss, ax  ;堆栈段指向代码段
    mov sp, BaseOfStack ;初始化栈指针到栈底
    call startFromBIOS ; 调用显示字符串例程

    ;=======================寻找 loader.bin=====================
    ; 软驱复位
    xor ah, ah ; 这两个操作都是取异或，那就是清零咯
    xor dl, dl ; 
    int 13h ; ah为0表示复位，dl表示复位后的驱动器号，0就是A盘 

    ; 下面在A 盘的根目录寻找 LOADER.BIN 
    mov word [wSectorNo], SectorNoOfRootDirectory 
LABEL_SEARCH_IN_ROOT_DIR_BEGIN: 
    cmp word [wRootDirSizeForLoop], 0 ; '. 判断根目录区是不是已经读完 
    jz LABEL_NO_LOADERBIN ; / 如果读完表示没有找到LOADER.BIN 
    dec word [wRootDirSizeForLoop] ; / 
    mov ax, BaseOfLoader 
    mov es, ax ; es <- BaseOfLoader 
    mov bx, OffsetOfLoader ; bx <- OffsetOfLoader 
    mov ax, [wSectorNo] ; ax <- Root Directory 中的某Sector 号 
    mov cl, 1 
    call ReadSector 

    mov si, LoaderFileName ; ds:si -> "LOADER BIN" 这里出了问题
    mov di, OffsetOfLoader ; es:di -> BaseOfLoader:0100 
    cld 
    mov dx, 10h ;这里的循环次数是一个扇区有多少条目，512/32=16个条目
LABEL_SEARCH_FOR_LOADERBIN: 
    cmp dx, 0 ; '. 循环次数控制 
    jz LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR ; / 如果已经读完了一个Sector 就跳到下一个Sector
    dec dx ;  
    mov cx, 11 
LABEL_CMP_FILENAME: 
    cmp cx, 0 
    jz LABEL_FILENAME_FOUND ; 如果比较了11 个字符都相等, 表示找到 
    dec cx 
    lodsb ; ds:si -> al 
    cmp al, byte [es:di]
    jz LABEL_GO_ON 
    jmp LABEL_DIFFERENT ; 只要发现不一样的字符就表明本DirectoryEntry ,不是我们要找的LOADER.BIN 
LABEL_GO_ON: 
    inc di 
    jmp LABEL_CMP_FILENAME ; 继续循环 

LABEL_DIFFERENT: ;判断文件名的字符出现不一致
    and di, 0FFE0h ; else '. di &= E0 为了让它指向本条目开头 
    add di, 20h ; | 
    mov si, LoaderFileName ; | di += 20h 
    jmp LABEL_SEARCH_FOR_LOADERBIN; / 

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR: ;继续循环判断下一条目
    add word [wSectorNo], 1 
    jmp LABEL_SEARCH_IN_ROOT_DIR_BEGIN 

LABEL_NO_LOADERBIN: ;最终没有找到loader.bin文件
    mov dh, 2 ; "No LOADER."这个玩意用2乘以msg的长度。然后加上bootmsg的基地址去选择要打印的信息 
    call DispStr ; 显示字符串 
    %ifdef _BOOT_DEBUG_ 
    mov ax, 4c00h ; '. 
    int 21h ; / 没有找到LOADER.BIN, 回到DOS 
    %else 
    jmp $ ; 没有找到LOADER.BIN, 死循环在这里 
    %endif 

LABEL_FILENAME_FOUND: ; 找到LOADER.BIN 后便来到这里继续
    mov dh, 1 ; "No LOADER."这个玩意用2乘以msg的长度。然后加上bootmsg的基地址去选择要打印的信息 
    call DispStr ; 显示字符串  

    ; 加载loader.bin
    mov ax, RootDirSectors ; RootDirSectors = 14
    and di, 0FFE0h ; di -> 当前条目的开始 
    add di, 01Ah ; di -> 首 Sector 
    mov cx, word [es:di] 
    push cx ; 保存此Sector在FAT中的序号 
    add cx, ax ;-------------
    add cx, DeltaSectorNo ; cl <- LOADER.BIN的起始扇区号(0-based) 
    mov ax, BaseOfLoader 
    mov es, ax ; es <- BaseOfLoader 
    mov bx, OffsetOfLoader; bx <- OffsetOfLoader 
    mov ax, cx ; ax <- Sector号 

LABEL_GOON_LOADING_FILE: 
    push ax ; '. 
    push bx ; | 
    mov ah, 0Eh ; | 每读一个扇区就在"Booting"后面 
    mov al, '.' ; | 打一个点,形成这样的效果: 
    mov bl, 0Fh ; | Booting ...... 
    int 10h ; | 
    pop bx ; | 
    pop ax ; / 

    mov cl, 1 
    call ReadSector 
    pop ax ; 取出此Sector在FAT中的序号 
    call GetFATEntry 
    cmp ax, 0FFFh 
    jz LABEL_FILE_LOADED 
    push ax ; 保存Sector在FAT中的序号 
    mov dx, RootDirSectors 
    add ax, dx 
    add ax, DeltaSectorNo 
    add bx, [BPB_BytsPerSec] 
    jmp LABEL_GOON_LOADING_FILE 
LABEL_FILE_LOADED: 
    jmp BaseOfLoader:OffsetOfLoader ; 这一句正式跳转到已加载到内 
                                    ; 存中的LOADER.BIN的开始处， 
                                    ; 开始执行LOADER.BIN的代码。 
                                    ; BootSector的使命到此结
;=======================end of寻找 loader.bin=====================

;=============================================================
; 变量 
wRootDirSizeForLoop dw RootDirSectors ; Root Directory 占用的扇区数，在循环中会递减至零 
wSectorNo dw 0 ; 要读取的扇区号 
bOdd db 0 ; 奇数还是偶数 

;=============================================================
; 字符串 
LoaderFileName db "LOADER  BIN", 0 ; LOADER.BIN 之文件名 ，FAT12不区分大小写
; 为简化代码, 下面每个字符串的长度均为MessageLength 
MessageLength equ 7 
BootMessage: db "Booting" ; 7字节, 不够则用空格补齐. 序号0 
Message1 db "Ready. " ; 7字节, 不够则用空格补齐. 序号1 
Message2 db "No find";7字节, 不够则用空补
;=============================================================


;----------------------------------------------------------------------------
; 函数名: startFromBIOS
;----------------------------------------------------------------------------
; 作用: boot程序一开始的简单工作，主要是清屏和显示一个字符串  
startFromBIOS: 
    ; 引导程序主要通过中断服务程序 INT 10h实现相关功能
    ; 服务程序使用的参数通过ax，bx，cx，dx 四个寄存器提供
    ;=========clean screen==========
    ; 接下来的介绍中AL代表ax寄存器低位，AH代表ax寄存器低位
    mov ax, 0600h ; AH=06表示滚动窗口，当AL=0时实现清屏，
    mov bx, 1700h ; 这里表示清屏后的属性为蓝色背景，白色字体
    mov cx, 0000h ; 左上角的列号(CH)，行号(CL)
    mov dx, 184fh ; 右下角的列号(DH)，行号(DL)
    int 10h
    ; =========set screen focus============
    ; dx代表光标位置，原点(0, 0)为左上角
    mov ax, 0200h
    mov bx, 0000h
    mov dx, 0000h
    int 10h
    ; ===========display on screen===========
    mov bp, BootMessage ; BP = 串地址 
    mov ax, 01301h ; AH = 13 显示字符串, AL = 01h 光标跟随显示移动 
    mov bx, 001fh ; 页号为0 (BH = 0) 蓝底白字(BL = 0Ch,高亮) 
    mov cx, MessageLength ; CX = 串长度
    mov dx, 0 
    int 10h ; 10h 号中断 
    ret


;----------------------------------------------------------------------------
; 函数名: DispStr
;----------------------------------------------------------------------------
; 作用: 显示一个字符串, 函数开始时 dh 中应该是字符串序号(0-based)
    ;modify by tianyu:加入了push es，保护函数调用前后环境
DispStr: 
    mov ax, MessageLength 
    mul dh 
    add ax, BootMessage 
    mov bp, ax ; '. 
    mov ax, ds ; | ES:BP = 串地址 
    push es  ;这个坑爹函数改变了es的内容，但是读盘的时候es都是0x9000,这里是0，而且没还原，出了bug
    mov es, ax ; / 
    mov cx, MessageLength ; CX = 串长度 
    mov ax, 01301h ; AH = 13, AL = 01h 
    mov bx, 001fh ; 页号为0(BH = 0) 蓝底白字(BL = 07h) 
    mov dl, 0
    mov dh, 1
    int 10h ; int 10h 
    pop es
    ret 


;----------------------------------------------------------------------------
; 函数名: ReadSector
;----------------------------------------------------------------------------
; 作用: 从第 ax 个 Sector 开始, 将 cl 个 Sector 读入 es:bx 中
ReadSector: 
	; -----------------------------------------------------------------------
	; 怎样由扇区号求扇区在磁盘中的位置 (扇区号 -> 柱面号, 起始扇区, 磁头号)
	; -----------------------------------------------------------------------
	; 设扇区号为 x
	;                           ┌ 柱面号 = y >> 1
	;       x           ┌ 商 y ┤
	; -------------- => ┤      └ 磁头号 = y & 1
	;  每磁道扇区数     │
	;                   └ 余 z => 起始扇区号 = z + 1
    push bp 
    mov bp, sp 
    sub esp, 2 ; 辟出两个字节的堆栈区域保存要读的扇区数: byte [bp-2] 

    mov byte [bp-2], cl 
    push bx ; 保存bx 
    mov bl, [BPB_SecPerTrk] ; bl: 除数 
    div bl ; y 在al 中, z 在ah 中 ，z=y/x
    inc ah ; z ++ 
    mov cl, ah ; cl <- 起始扇区号 
    mov dh, al ; dh <- y 
    shr al, 1 ; y >> 1 (y/BPB_NumHeads) 
    mov ch, al ; ch <- 柱面号 
    and dh, 1 ; dh & 1 = 磁头号 
    pop bx ; 恢复bx 
    ; 至此, "柱面号, 起始扇区, 磁头号" 全部得到 
    mov dl, [BS_DrvNum] ; 驱动器号（0 表示A 盘） 
    .GoOnReading: 
    mov ah, 2 ; 读 
    mov al, byte [bp-2] ; 读al 个扇区 
    int 13h 
    jc .GoOnReading ; 如果读取错误CF 会被置为1 
    ; 这时就不停地读, 直到正确为止 
    add esp, 2 
    pop bp 

    ret 

;----------------------------------------------------------------------------
; 函数名: GetFATEntry
;----------------------------------------------------------------------------
; 作用:
;	找到序号为 ax 的 Sector 在 FAT 中的条目, 结果放在 ax 中
;	需要注意的是, 中间需要读 FAT 的扇区到 es:bx 处, 所以函数一开始保存了 es 和 bx

; 获取FAT表中的entry，这是为了当loader.bin程序大于512字节时，跨越多个扇区，需要重复读取FAT
; entry来获取下一个扇区的地点，所以封装函数，输入扇区号，输出FAT entry的值，即下一扇区的值
; 这个函数我们就不细看了，无非就是判断奇数偶数的entry去做计算而已，(entry占12bit)

GetFATEntry: 
    push es 
    push bx 
    push ax 
    mov ax, BaseOfLoader; '. 
    sub ax, 0100h ; | 在BaseOfLoader 后面留出4K 空间用于存放FAT ，FAT=9*512=4K
    mov es, ax ; / 
    pop ax 
    mov byte [bOdd], 0 
    mov bx, 3 
    mul bx ; dx:ax = ax * 3 
    mov bx, 2 
    div bx ; dx:ax / 2 ==> ax <- 商, dx <- 余数 
    cmp dx, 0 
    jz LABEL_EVEN 
    mov byte [bOdd], 1 
    LABEL_EVEN: ; 偶数 
    ; 现在ax 中是FATEntry 在FAT 中的偏移量,下面来 
    ; 计算FATEntry 在哪个扇区中(FAT占用不止一个扇区) 
    xor dx, dx 
    mov bx, [BPB_BytsPerSec] 
    div bx ; dx:ax / BPB_BytsPerSec
    ; ax <- 商(FATEntry 所在的扇区相对于FAT 的扇区号) 
    ; dx <- 余数(FATEntry 在扇区内的偏移) 
    push dx 
    mov bx, 0 ; bx <- 0 于是, es:bx = (BaseOfLoader - 100):00 
    add ax, SectorNoOfFAT1 ; 此句之后的ax 就是FATEntry 所在的扇区号 
    mov cl, 2 
    call ReadSector ; 读取FATEntry 所在的扇区, 一次读两个, 避免在边界 
    ; 发生错误, 因为一个FATEntry 可能跨越两个扇区 
    pop dx 
    add bx, dx 
    mov ax, [es:bx] 
    cmp byte [bOdd], 1 
    jnz LABEL_EVEN_2 
    shr ax, 4 
    LABEL_EVEN_2: 
    and ax, 0FFFh 

    LABEL_GET_FAT_ENRY_OK: 

    pop bx 
    pop es 
    ret 


;--------------------------------------------------------
times 510 - ($-$$) db 0 ; 填充剩下的空间，使生成的二进制代码恰好为512字节 
dw 0xaa55 ; 结束标志


