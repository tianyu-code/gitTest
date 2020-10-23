
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            main.c
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                                                    Forrest Yu, 2005
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/


#include "type.h"
#include "const.h"
#include "protect.h"
#include "protectFunc.h"
#include "string.h"
#include "proc.h"
#include "global.h"


void TestA();
void TestB();
void TestC();

/*======================================================================*
                            kernel_main
 *======================================================================*/
int kernel_main()
{
	disp_str("-----\"kernel_main\" begins-----\n");

	//为了能够成功跳转到第一个进程，填充PCB表的第一个元素
	PROCESS* p_proc	= proc_table;
	TASK*	p_task		= task_table;
	char*	p_task_stack	= task_stack + STACK_SIZE_TOTAL;
	u16		selector_ldt	= SELECTOR_LDT_FIRST;
	int i;

	TASK	tmp_task[NR_TASKS] = {{TestA, STACK_SIZE_TESTA, "TestA"},
					{TestB, STACK_SIZE_TESTB, "TestB"},
					{TestC, STACK_SIZE_TESTC, "TestC"}
					};
	memcpy(task_table, tmp_task, sizeof(task_table));

	for(i = 0;i < NR_TASKS;i++){
		strcpy(p_proc->p_name, p_task->name);	// name of the process
		p_proc->pid = i;			// pid

		//初始化ldt段描述符和选择子
		p_proc->ldt_sel = selector_ldt;
		memcpy(&p_proc->ldts[0], &gdt[SELECTOR_KERNEL_CS>>3], sizeof(DESCRIPTOR));//ldt表第一项其实就是GDT中的CS段描述符
		p_proc->ldts[0].attr1 = DA_C | PRIVILEGE_TASK << 5;	// change the DPL，然后把它特权级改了，这样进程就能访问了
		memcpy(&p_proc->ldts[1], &gdt[SELECTOR_KERNEL_DS>>3], sizeof(DESCRIPTOR));//后面是类似的操作
		p_proc->ldts[1].attr1 = DA_DRW | PRIVILEGE_TASK << 5;	// change the DPL

		//这里初始化的寄存器，大部分都是在LDT中的选择子,SA_TI_MASK是将ti何rpl位清空，SA_TIL代表从ldt中索引，RPL_TASK代表ring1特权级
		p_proc->regs.cs	= (0 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;//指向LDT中的第一个描述符
		p_proc->regs.ds	= (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;//ds,es,fs,ss都指向LDT中的第二个描述符
		p_proc->regs.es	= (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
		p_proc->regs.fs	= (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
		p_proc->regs.ss	= (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
		p_proc->regs.gs	= (SELECTOR_KERNEL_GS & SA_RPL_MASK) | RPL_TASK;	//gs仍然指向显存，只不过特权级变了

		p_proc->regs.eip= (u32)p_task->initial_eip;//每个进程的代码段地址，填充到PCB的eip中，一会ret的时候就能跳过去了
		p_proc->regs.esp= (u32) p_task_stack;//堆栈从高地址开始，所以 + STACK_SIZE_TOTAL
		p_proc->regs.eflags = 0x1202;	// IF=1表示打开终端, IOPL=1表示使能IO, bit 2 is always 1.这样在进入ring1的进程中执行后，中断和IO就都使能了

		//那8个通用寄存器在第一次进入的时候没啥用，不用初始化

		p_task_stack -= p_task->stacksize;//为每个进程分配堆栈空间
		p_proc++;//初始化下一个进程
		p_task++;
		selector_ldt += 1 << 3;//ldt段描述符在GDT中的索引加一，左移3bit是代表TI和RPL位
	}

	k_reenter = 0;//中断嵌套标志位

	p_proc_ready	= proc_table;//从第一个进程开始执行


	put_irq_handler(CLOCK_IRQ, clock_handler); /* 设定时钟中断处理程序 */
    enable_irq(CLOCK_IRQ);                     /* 让8259A可以接收时钟中断 */

	restart();

	while(1){}
}

/*======================================================================*
                               TestA
 *======================================================================*/
void TestA()
{
	int i = 0;
	while(1){
		// get_ticks();
		disp_str("A");
		disp_int(i++);
		disp_str(".");
		delay(1);
	}
}

void TestB()
{
	int i = 0x1000;
	while(1){
		disp_str("B");
		disp_int(i++);
		disp_str(".");
		delay(1);
	}
}

/*======================================================================*
                               TestC
 *======================================================================*/
void TestC()
{
	int i = 0x2000;
	while(1){
		disp_str("C");
		disp_int(i++);
		disp_str(".");
		delay(1);
	}
}
