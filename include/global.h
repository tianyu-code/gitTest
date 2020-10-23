
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            global.h
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

#include "proc.h"

extern	int		    disp_pos;
extern	u8		    gdt_ptr[6];	/* 0~15:Limit  16~47:Base */
extern	DESCRIPTOR	gdt[GDT_SIZE];
extern	u8		    idt_ptr[6];	/* 0~15:Limit  16~47:Base */
extern	GATE		idt[IDT_SIZE];

extern u32		k_reenter;//中断嵌套标志位

extern	TSS		    tss;
extern	PROCESS*	p_proc_ready;//进程控制表

extern	PROCESS		proc_table[NR_TASKS];//进程控制表
extern	char		task_stack[STACK_SIZE_TOTAL];
extern TASK	        task_table[NR_TASKS];

extern irq_handler		    irq_table[NR_IRQ];