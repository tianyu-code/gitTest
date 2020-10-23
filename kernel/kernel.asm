; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                               kernel.asm
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

%include "sconst.inc"

; 导入函数
extern	cstart				;初始化中断，IDT，GDT等全局的配置
extern	kernel_main			;初始化进程相关结构
extern	exception_handler	;内部中断处理
extern	spurious_irq		;外部中断处理
extern	delay				;小延时函数
extern	clock_handler		;时钟中断的核心处理函数，后续估计要在这里添加进程调度



; 导入全局变量
extern	gdt_ptr			;保存GDT寄存器
extern	idt_ptr			;保存IDT寄存器
extern	p_proc_ready	;进程控制表
extern	tss				;TSS结构变量
extern	disp_pos		;打印函数用来控制位置的全局变量
extern	k_reenter		;中断嵌套控制
extern sys_call_table
extern irq_table

bits 32

[SECTION .data]
clock_int_msg		db	"^", 0

[SECTION .bss]
StackSpace		resb	2 * 1024
StackTop:		; 栈顶,此处为内核栈

[section .text]	; 代码在此

global _start	; 导出 _start
global restart
global sys_call


global	divide_error
global	single_step_exception
global	nmi
global	breakpoint_exception
global	overflow
global	bounds_check
global	inval_opcode
global	copr_not_available
global	double_fault
global	copr_seg_overrun
global	inval_tss
global	segment_not_present
global	stack_exception
global	general_protection
global	page_fault
global	copr_error
global  hwint00
global  hwint01
global  hwint02
global  hwint03
global  hwint04
global  hwint05
global  hwint06
global  hwint07
global  hwint08
global  hwint09
global  hwint10
global  hwint11
global  hwint12
global  hwint13
global  hwint14
global  hwint15

_start:
	; 把 esp 从 LOADER 挪到 KERNEL
	mov	esp, StackTop	; 堆栈在 bss 段中

	sgdt	[gdt_ptr]	; cstart() 中将会用到 gdt_ptr
	call	cstart		; 在此函数中改变了gdt_ptr，让它指向新的GDT
	lgdt	[gdt_ptr]	; 使用新的GDT

	lidt	[idt_ptr]

	jmp	SELECTOR_KERNEL_CS:csinit
csinit:		

	;ud2	;触发BIOS中段号6，UD，未定义的操作码错误
		; 触发中断之后，系统会立刻将eflag，cs和eip入栈
	;jmp 0x40:0	;这个指令是一个错误指令，目的就是为了触发一个#NP 异常，进入中断处理函数
	
	; sti
	; hlt		;处理器暂停指令
	; jmp $
	xor	eax, eax
	mov	ax, SELECTOR_TSS
	ltr	ax				;在ring0初始化TR寄存器，TSS的内容后面再填充

	jmp	kernel_main		;进入该函数初始化进程控制表和TSS，然后ret从ring0->ring1



; 中断和异常 -- 硬件中断
; ---------------------------------	
%macro	hwint_master	1
	call	save
	; inc byte [gs:0] ; 改变屏幕第0 行, 第0 列的字符
	in	al, INT_M_CTLMASK	; `.
	or	al, (1 << %1)		;  | 屏蔽当前中断,即不会发生本中断的嵌套
	out	INT_M_CTLMASK, al	; /
	mov	al, EOI				; `. 置EOI位
	out	INT_M_CTL, al		; /
	sti	; CPU在响应中断的过程中会自动关中断，这句之后就允许响应新的中断
	push	%1						; `.
	call	[irq_table + 4 * %1]	;  | 中断处理程序
	pop	ecx							; /
	cli
	in	al, INT_M_CTLMASK	; `.
	and	al, ~(1 << %1)		;  | 恢复接受当前中断
	out	INT_M_CTLMASK, al	; /
	ret
%endmacro
; ---------------------------------

ALIGN   16
hwint00:                ; Interrupt routine for irq 0 (the clock).
		hwint_master 0


ALIGN   16
hwint01:                ; Interrupt routine for irq 1 (keyboard)
        hwint_master    1

ALIGN   16
hwint02:                ; Interrupt routine for irq 2 (cascade!)
        hwint_master    2

ALIGN   16
hwint03:                ; Interrupt routine for irq 3 (second serial)
        hwint_master    3

ALIGN   16
hwint04:                ; Interrupt routine for irq 4 (first serial)
        hwint_master    4

ALIGN   16
hwint05:                ; Interrupt routine for irq 5 (XT winchester)
        hwint_master    5

ALIGN   16
hwint06:                ; Interrupt routine for irq 6 (floppy)
        hwint_master    6

ALIGN   16
hwint07:                ; Interrupt routine for irq 7 (printer)
        hwint_master    7

; ---------------------------------
%macro  hwint_slave     1
        push    %1
        call    spurious_irq
        add     esp, 4
        hlt
%endmacro
; ---------------------------------

ALIGN   16
hwint08:                ; Interrupt routine for irq 8 (realtime clock).
        hwint_slave     8

ALIGN   16
hwint09:                ; Interrupt routine for irq 9 (irq 2 redirected)
        hwint_slave     9

ALIGN   16
hwint10:                ; Interrupt routine for irq 10
        hwint_slave     10

ALIGN   16
hwint11:                ; Interrupt routine for irq 11
        hwint_slave     11

ALIGN   16
hwint12:                ; Interrupt routine for irq 12
        hwint_slave     12

ALIGN   16
hwint13:                ; Interrupt routine for irq 13 (FPU exception)
        hwint_slave     13

ALIGN   16
hwint14:                ; Interrupt routine for irq 14 (AT winchester)
        hwint_slave     14

ALIGN   16
hwint15:                ; Interrupt routine for irq 15
        hwint_slave     15

; 中断和异常 -- 异常
divide_error:
	push	0xFFFFFFFF	; no err code
	push	0		; vector_no	= 0
	jmp	exception
single_step_exception:
	push	0xFFFFFFFF	; no err code
	push	1		; vector_no	= 1
	jmp	exception
nmi:
	push	0xFFFFFFFF	; no err code
	push	2		; vector_no	= 2
	jmp	exception
breakpoint_exception:
	push	0xFFFFFFFF	; no err code
	push	3		; vector_no	= 3
	jmp	exception
overflow:
	push	0xFFFFFFFF	; no err code
	push	4		; vector_no	= 4
	jmp	exception
bounds_check:
	push	0xFFFFFFFF	; no err code
	push	5		; vector_no	= 5
	jmp	exception
inval_opcode:
	push	0xFFFFFFFF	; no err code
	push	6		; vector_no	= 6
	jmp	exception
copr_not_available:
	push	0xFFFFFFFF	; no err code
	push	7		; vector_no	= 7
	jmp	exception
double_fault:
	push	8		; vector_no	= 8
	jmp	exception
copr_seg_overrun:
	push	0xFFFFFFFF	; no err code
	push	9		; vector_no	= 9
	jmp	exception
inval_tss:
	push	10		; vector_no	= A
	jmp	exception
segment_not_present:
	push	11		; vector_no	= B
	jmp	exception
stack_exception:
	push	12		; vector_no	= C
	jmp	exception
general_protection:
	push	13		; vector_no	= D
	jmp	exception
page_fault:
	push	14		; vector_no	= E
	jmp	exception
copr_error:
	push	0xFFFFFFFF	; no err code
	push	16		; vector_no	= 10h
	jmp	exception

exception:
	call	exception_handler
	add	esp, 4*2	; 让栈顶指向 EIP，堆栈中从顶向下依次是：EIP、CS、EFLAGS
	hlt


; ====================================================================================
;                                   save
; ====================================================================================
save:
	pushad          ; `.
	push    ds      ;  |
	push    es      ;  | 保存原寄存器值
	push    fs      ;  |
	push    gs      ; /
	mov     dx, ss
	mov     ds, dx
	mov     es, dx

	mov     esi, esp                    ;esi = 进程表起始地址

	;为什么这个save函数没用ret返回？因为esp有可能改变，不能直接弹栈获得正确的eip
	inc     dword [k_reenter]           ;k_reenter++;
	cmp     dword [k_reenter], 0        ;if(k_reenter ==0)
	jne     .1                          ;{
	mov     esp, StackTop               ;  mov esp, StackTop <--切换到内核栈
	push    restart                     ;  push restart
	jmp     [esi + RETADR - P_STACKBASE];  return;,这个RETADR就是call save时压栈的eip
.1:                                         ;} else { 已经在内核栈，不需要再切换
	push    restart_reenter             ;  push restart_reenter
	jmp     [esi + RETADR - P_STACKBASE];  return;
                                            ;}

; ====================================================================================
;                                 sys_call，系统调用的中断处理函数
; ====================================================================================
sys_call:
        call    save

        sti

        call    [sys_call_table + eax * 4]	;根据系统调用号eax，去调用具体的处理函数
        mov     [esi + EAXREG - P_STACKBASE], eax	;返回值通过eax寄存器返回给用户

        cli

        ret

; ====================================================================================
;       restart：该函数是进入ring0->ring1的关键，需要汇编实现，所以放在这里了
; ====================================================================================
restart:
	mov	esp, [p_proc_ready]		;esp指向PCB的开头
	lldt	[esp + P_LDT_SEL] 	;P_LDT_SEL是ldt选择子在PCB的偏移，填充ldtr寄存器
	lea	eax, [esp + P_STACKTOP]	;lea命令是取地址，即PCB结构中的堆栈的顶部
	mov	dword [tss + TSS3_S_SP0], eax	;填充TSS结构中的ring0的堆栈地址
restart_reenter:
	dec dword [k_reenter]
	pop	gs
	pop	fs
	pop	es
	pop	ds
	popad	;8个通用寄存器弹栈

	add	esp, 4	;跳过retaddr

	iretd	;从ring0跳到ring1，将eip，cs等一系列寄存器弹栈
