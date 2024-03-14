__sp = 0x10000;

SECTIONS
{
    . = 0x00000000;

    .text.init : {
        *(.text.init)
    }

    .text : {
        *(.text)
    }

    __global_pointer$ = . + 0x800;

    .rodata : {
        *(.rodata*)
        *(.srodata*)
    }

    .data : {
        *(.data*)
        *(.sdata)
        *(.got*)
    }

    .bss : {
        __bss_start = .; PROVIDE(bss_start = .);
        *(.sbss)
        *(COMMON)
        *(.bss)
        _edata = .; PROVIDE (edata = .);
    }

    _end = .; PROVIDE(end = .);
}
