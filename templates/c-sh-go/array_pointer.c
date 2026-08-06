int main(void) {
    int a[3] = {10, 20, 30};
    int *p = &a[1];
    printf("%d\n", *p);
    printf("%d\n", p[1]);
    return 0;
}
