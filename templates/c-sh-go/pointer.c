int main(void) {
    int x = 5;
    int *p = &x;
    *p = 7;
    printf("%d\n", x);
    return 0;
}
