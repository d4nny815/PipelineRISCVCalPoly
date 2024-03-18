#define DELAY_TIME 0xfff
// #define DELAY_TIME 0xf

void delay(int n);
void johnson_led();
void toggle_led(int*);
void output_led(int*);
int get_btn();

volatile int* const LED_REG = (int*)0x1100C000; 
volatile int* const BTN_REG = (int*)0x11008004;

int main(void) {
    // int btn;
    int led = 0x0001;
    int* p_led = &led;
    output_led(p_led);
    while (1) {
        led ^= 1;
        *LED_REG = led;
        delay(DELAY_TIME);
        // toggle_led(p_led);
        // btn = get_btn();
        // if (btn == 0) toggle_led(p_led);
        // else johnson_led();
    }
    return 0;
}

int get_btn() {
    int btn = *BTN_REG;
    return btn & 0xf;
}

void output_led(int* led) {
    *LED_REG = *led;
    return;
}

void toggle_led(int* led) {
    *led = *led ^ 1;
    output_led(led);
    delay(DELAY_TIME);
    return;
}

void johnson_led() {
    int total_leds = 16;    
    int led = 0x0001;
    int left_most_led = 1 << (total_leds - 1);

    for (int i=0; i<total_leds; i++) {
        *LED_REG = led;
        delay(DELAY_TIME);
        led = led >> 1;
        led = led | left_most_led;
    }

    for (int i=0; i<total_leds; i++) {
        *LED_REG = led;
        delay(DELAY_TIME);
        led = led >> 1;
    }

    *LED_REG = 0x0000;
    return;
}

void delay(int n) {
    volatile int i;
    for (i = 0; i < n; i++);
    return;
}

