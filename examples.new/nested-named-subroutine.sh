#!/bin/bash
# Nested function definition inside another function
outer() {
    inner() {
        echo "inner function"
    }
    inner
}
outer
