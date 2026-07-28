#!/bin/bash
# Nested function inside another function
outer() {
    inner() {
        echo "inner function"
    }
    inner
}
outer
