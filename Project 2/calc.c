#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    if (argc != 6) {
        printf("Missing args\n");
        return 1;
    }

    int a = atoi(argv[1]);
    int b = atoi(argv[2]);
    int c = atoi(argv[3]);
    int d = atoi(argv[4]);
    int e = atoi(argv[5]);

    
    printf("op1 = %d\n", a + b);
    printf("op2 = %d\n", (a + b) * 42);
    printf("op3 = %d\n", c * d);
    printf("op4 = %d\n", a - e);
    printf("op5 = %d\n", c * d * (a - e));
    printf("Result = %d\n", ((a + b) * 42) - (c * d * (a - e)));
    
    return 0;
}