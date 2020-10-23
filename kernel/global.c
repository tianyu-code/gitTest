
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            global.c
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/


#include "global.h"
#include "protectFunc.h"

u8		    gdt_ptr[6];	/* 0~15:Limit  16~47:Base */
DESCRIPTOR	gdt[GDT_SIZE];
u8		    idt_ptr[6];	/* 0~15:Limit  16~47:Base */
GATE		idt[IDT_SIZE];

u32		    k_reenter;

TSS		    tss;
PROCESS*	p_proc_ready;//进程控制表

PROCESS		proc_table[NR_TASKS];//进程控制表
char		task_stack[STACK_SIZE_TOTAL];
TASK	    task_table[NR_TASKS];

irq_handler		irq_table[NR_IRQ];

system_call		sys_call_table[NR_SYS_CALL] = {sys_get_ticks};