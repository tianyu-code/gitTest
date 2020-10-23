
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            protectFunc.h
内核函数声明，包含klib.c中的底层封装函数和i8259.c, protect.c
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

#include "type.h"

/* klib.asm */
void	out_byte(u16 port, u8 value);
u8	    in_byte(u16 port);
void	disp_str(char * info);
void	disp_color_str(char * info, int color);

/* protect.c */
void	init_prot();
void	init_8259A();
void    spurious_irq(int irq);
u32	seg2phys(u16 seg);

/* klib.c */
void	delay(int time);

/* kernel.asm */
void restart();

/*clock.c*/
void clock_handler(int irq);


/* 以下是系统调用相关 */
/* kernel.asm */
void    sys_call();             /* int_handler */

/* proc.c */
int     sys_get_ticks();        /* sys_call */

/* syscall.asm */
int     get_ticks();//这个是给用户使用的系统调用函数
