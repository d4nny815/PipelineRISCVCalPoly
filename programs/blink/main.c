volatile int* const LED_REG = (int*)0x1100C000; 

int main(void) {
    int led = 0;
    
    while (1) {
        *LED_REG = led;
        led ^= 1;
        volatile int i = 0;
        // for (i = 0; i < 0xFFFF; i++);
        for (i = 0; i < 0x7FFFFF; i++);

    }
    return 0;
}