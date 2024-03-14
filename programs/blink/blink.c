

volatile int* const LED_REG = (int*)0x1100C000; 

int main(void) {
    int led = 0;
    while (1) {
        *LED_REG = led;
        led ^= 1;
    }
    return 0;
}