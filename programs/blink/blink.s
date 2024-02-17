.text
    li s0, 0x1100C000           # LED port addr
    li a0, 1                    # current LED state

loop:
    xori a0, a0, 1              # toggle LED
    sw a0, 0(s0)                # output LED value
    call delay                  # delay
    j loop                      # loop back infinitely

delay:
    li t0, 0x7FFFFF             # Blink time (enter eqn)
    #li t0, 0xF             # Blink time (enter eqn)
delay_loop:
    addi t0, t0, -1             # decrement timer
    bne zero, t0, delay_loop    # loop if timer not done
    ret
    
